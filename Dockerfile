FROM ubuntu:20.04

ENV QORC_SDK_PATH=/home/qorc-sdk/qorc-sdk

RUN useradd -p locked -m qorc-sdk -G dialout

RUN apt-get update && apt-get install -y \
   git \
   sudo \
   wget \
   curl \
   lbzip2 \
   libtbb2

RUN mkdir -p /home/qorc-sdk && chown qorc-sdk:qorc-sdk -R /home/qorc-sdk

USER qorc-sdk

# FIXME: use fixed commit instead of master
RUN git clone https://github.com/QuickLogic-Corp/qorc-sdk.git $QORC_SDK_PATH

# Toolchains are downloaded and configured on first inclusion of this script.
# Do it now to save time later.
#
# Even though 'sudo' is installed, it will print errors because below command
# isn't run in terminal. Nevertheless, steps that require root permissions
# have to be performed on host system, not in Docker.
#
# Note that 'sudo' still must be installed, without it Python throws an
# exception instead of "completing successfully with errors".
RUN /bin/bash -ic ". $QORC_SDK_PATH/envsetup.sh"

# Library provided by toolchain doesn't work, use system library instead
RUN mv $QORC_SDK_PATH/fpga_toolchain_install/v1.3.1/conda/lib/libffi.so.7 \
       $QORC_SDK_PATH/fpga_toolchain_install/v1.3.1/conda/lib/libffi.so.7.backup

WORKDIR /home/qorc-sdk

RUN echo ". $QORC_SDK_PATH/envsetup.sh" > .bashrc
