-- #################################################################################################
-- # << NEORV32 - Custom Functions Subsystem (CFS) >>                                              #
-- # ********************************************************************************************* #
-- # This CFS implements the "Physical Unclonable Function (PUF)" <fpga_puf>. Make sure to replace #
-- # the default CFS file (neorv32_rtl/core/neorv32_cfs.vhd) by this one.                          #
-- #                                                                                               #
-- # Address map:                                                                                  #
-- # * NEORV32_CFS.REG[0] (r/w) (@cfs_reg0_addr_c): Control register                               #
-- #   * bit 0: Enable (r/w), set high to enable unit, set low to reset unit                       #
-- #   * bit 1: Trigger (r/w), set one to trigger ID sampling, clears when sampling is done        #
-- # * NEORV32_CFS.REG[1] (r/-) (@cfs_reg1_addr_c): PUF ID bits 31..0                              #
-- # * NEORV32_CFS.REG[2] (r/-) (@cfs_reg2_addr_c): PUF ID bits 63..32                             #
-- # * NEORV32_CFS.REG[3] (r/-) (@cfs_reg3_addr_c): PUF ID bits 95..64                             #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cfs is
  generic (
    CFS_CONFIG   : std_ulogic_vector(31 downto 0); -- custom CFS configuration generic
    CFS_IN_SIZE  : positive; -- size of CFS input conduit in bits
    CFS_OUT_SIZE : positive  -- size of CFS output conduit in bits
  );
  port (
    -- host access --
    clk_i       : in  std_ulogic; -- global clock line
    rstn_i      : in  std_ulogic; -- global reset line, low-active, use as async
    bus_req_i   : in  bus_req_t; -- bus request
    bus_rsp_o   : out bus_rsp_t := rsp_terminate_c; -- bus response
    clkgen_en_o : out std_ulogic := '0'; -- enable clock generator
    clkgen_i    : in  std_ulogic_vector(7 downto 0); -- "clock" inputs
    irq_o       : out std_ulogic := '0'; -- interrupt request
    cfs_in_i    : in  std_ulogic_vector(CFS_IN_SIZE-1 downto 0); -- custom inputs
    cfs_out_o   : out std_ulogic_vector(CFS_OUT_SIZE-1 downto 0) := (others => '0') -- custom outputs
  );
end neorv32_cfs;

architecture neorv32_cfs_rtl of neorv32_cfs is
  -- control register bits --
  constant ctrl_en_c     : natural := 0; -- r/w: unit enable (reset when disabled)
  constant ctrl_sample_c : natural := 1; -- r/w: set to trigger ID sampling, clears when sampling is done

  -- accessible registers --
  signal enable  : std_ulogic;
  signal trigger : std_ulogic;
  signal busy    : std_ulogic;
  signal puf_id  : std_ulogic_vector(95 downto 0);

  -- component: FPGA PUF IP --
  component fpga_puf
  port (
    clk_i  : in  std_ulogic; -- global clock line
    rstn_i : in  std_ulogic; -- SYNC reset, low-active
    trig_i : in  std_ulogic; -- set high for one clock to trigger ID sampling
    busy_o : out std_ulogic; -- busy when set (sampling ID)
    id_o   : out std_ulogic_vector(95 downto 0) -- PUF ID (valid after sampling is done)
  );
  end component;

begin
  -- LEDs --
  cfs_out_o <= (
    0 => busy,
    others => '0'
  );

  -- unused --
  clkgen_en_o <= '0';
  irq_o <= '0';

  -- Read/Write Access ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  host_access: process(clk_i)
  begin
    if (rstn_i = '0') then
      trigger <= '0';
      bus_rsp_o.ack  <= '0';
      bus_rsp_o.err  <= '0';
      bus_rsp_o.data <= (others => '0');
    elsif rising_edge(clk_i) then
      -- transfer/access acknowledge --
      bus_rsp_o.ack <= bus_req_i.stb;

      -- tie to zero if not explicitly used --
      bus_rsp_o.err <= '0';

      -- defaults --
      bus_rsp_o.data <= (others => '0'); -- the output HAS TO BE ZERO if there is no actual (read) access

      trigger <= '0';

      if (bus_req_i.stb = '1') then
        if (bus_req_i.rw = '1') then
          -- write access --
          case bus_req_i.addr(3 downto 2) is
            when "00" =>
              enable  <= bus_req_i.data(ctrl_en_c);
              trigger <= bus_req_i.data(ctrl_sample_c);
            when others => NULL;
          end case;
        else
          -- read access --
          case bus_req_i.addr(3 downto 2) is
            when "00" => bus_rsp_o.data(ctrl_en_c) <= enable; bus_rsp_o.data(ctrl_sample_c) <= busy; -- busy flag
            when "01" => bus_rsp_o.data <= puf_id(31 downto 00);
            when "10" => bus_rsp_o.data <= puf_id(63 downto 32);
            when "11" => bus_rsp_o.data <= puf_id(95 downto 64);
            when others => NULL;
          end case;
        end if;
      end if;
    end if;
  end process host_access;


  -- PUF IP Block ---------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  fpga_puf_inst: fpga_puf
  port map (
    clk_i  => clk_i,
    rstn_i => enable,
    trig_i => trigger,
    busy_o => busy,
    id_o   => puf_id
  );


end neorv32_cfs_rtl;
