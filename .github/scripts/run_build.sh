#!/bin/bash
#
# builds all executables
#

# getting updated environment (CUDA_HOME, PATH, ..)
if [ -f $HOME/.tmprc ]; then source $HOME/.tmprc; fi

WORKDIR=`pwd`

# info
echo "work directory: $WORKDIR"
echo `date`
echo
echo "**********************************************************"
echo
echo "configuration test: TESTFLAGS=${TESTFLAGS} TESTNGLL=${TESTNGLL}"
echo
echo "**********************************************************"
echo

# compiler infos
echo "compiler versions:"
echo "gcc --version"
gcc --version
echo "gfortran --version"
gfortran --version
echo "mpif90 --version"
mpif90 --version
echo

## ADIOS2
if [ "${ADIOS2}" == "true" ]; then
  echo
  echo "enabling ADIOS2"
  echo
  ADIOS2_CONFIG="${ADIOS2_DIR}/bin/adios2-config"
  adios=(--with-adios2 ADIOS2_CONFIG="$ADIOS2_CONFIG" )
else
  adios=()
fi

## HIP
if [ "${HIP}" == "true" ]; then
  echo
  echo "enabling HIP"
  echo
  hip=(--with-hip HIPCC=g++ HIP_FLAGS="-O2 -g -std=c++17" HIP_PLATFORM=cpu HIP_INC=./external_libs/ROCm-HIP-CPU/include HIP_LIBS="-ltbb -lpthread -lstdc++")
else
  hip=()
fi

# configuration
echo
echo "configuration:"
echo

./configure \
"${adios[@]}" \
"${hip[@]}" \
FC=gfortran MPIFC=mpif90 CC=gcc ${TESTFLAGS}

# checks
if [[ $? -ne 0 ]]; then echo "configuration failed:"; cat config.log; echo ""; echo "exiting..."; exit 1; fi

# layered example w/ NGLL = 6
if [ "$TESTNGLL" == "6" ]; then
  sed -i "s:NGLLX =.*:NGLLX = 6:" setup/constants.h
fi

# we output to console
sed -i "s:IMAIN .*:IMAIN = ISTANDARD_OUTPUT:" setup/constants.h

# compilation
echo
echo "clean:"
make clean

echo
echo "compilation:"
make -j4 all

# checks
if [[ $? -ne 0 ]]; then exit 1; fi

echo
echo "done "
echo `date`
echo
