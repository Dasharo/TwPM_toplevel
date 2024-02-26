n_cells = 0

ctx.createRectangularRegion("puf", 1, 1, 14, 14)
ctx.createRectangularRegion("everything_else", 14, 14, 72, 50)
for name, info in ctx.cells:
    if name.startswith(
        "cpu.neorv32_top_inst.io_system_neorv32_cfs_inst_true_neorv32_cfs_inst.fpga_puf_inst"
    ):
        ctx.constrainCellToRegion(name, "puf")
        n_cells += 1
    else:
        ctx.constrainCellToRegion(name, "everything_else")


print(f"Info: Constrained {n_cells} PUF cells")
