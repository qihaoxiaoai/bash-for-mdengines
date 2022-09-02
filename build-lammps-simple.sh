#!/bin/bash
#########
##racyhe
##qihaoxiaoai@gmail.com
#########
set -e
module purge
module load gcc/5.4.0
module load openmpi/3.1.4-gnu-5.4.0
export PATH=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/bin:$PATH
export C_INCLUDE_PATH=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/include:$CPLUS_INCLUDE_PATH
source /home/xhshi/hjx/software/cmake-3.19.8-Linux-x86_64/env.sh
source /home/xhshi/hjx/software-self/lammps-simple/old/source-plumed.sh
INSTALL_DIR=/home/xhshi/hjx/software-self/lammps-simple/old/lmp_plu
BuildMPI=yes
LAMMPS_VERSION=stable_29Sep2021_update3
Make_CPUs=20
PLUMED_LinkMode=static
#static;shared;runtime


if [[  -z ${PLUMED_KERNEL} ]]; then
  echo "The PLUMED environmental variables seen to be missing"
  echo "Did you run source source-plumed.sh?"
  exit 0
fi

if [[  -z ${PLUMED_INSTALL_DIR} ]]; then
  echo "The PLUMED environmental variables seen to be missing"
  echo "Did you run source source-plumed.sh?"
  exit 0
fi

if  [[ ! -x "$(command -v plumed)" ]]; then
  echo "The plumed command seems to be missing from the path" 
  echo "Did you run source source-plumed.sh?"
  exit 0
fi

if  ! plumed config -q has mpi  && [[ ${BuildMPI} == "yes" ]]; then 
  echo "You are trying to compile LAMMPS with MPI while PLUMED has been compiled without MPI"
  echo "Set BuildMPI to no in the script" 
  exit 0
fi


# Download and build LAMMPS 
if [[ -e ${LAMMPS_VERSION}.zip ]]; then
  echo "the ${LAMMPS_VERSION}.zip that we want to download already exists, please delete it to be sure that the file is properly downloaded"
  exit 0
fi
if [[ -e lammps-${LAMMPS_VERSION} ]]; then
  echo "the lammps-${LAMMPS_VERSION} folder from unzipping the ${LAMMPS_VERSION}.zip already exists, please delete it to be sure that the build is clean"
  exit 0
fi

wget --no-cookie --no-check-certificate -e robots=off https://github.com/lammps/lammps/archive/refs/tags/${LAMMPS_VERSION}.zip
unzip ${LAMMPS_VERSION}.zip 
rm -f ${LAMMPS_VERSION}.zip 
cd lammps-${LAMMPS_VERSION}


if [[ ${BuildMPI} == "no" ]]; then 
  # Since this version is not compiled with MPI, it should not pass a communicator to PLUMED
  cat src/USER-PLUMED/fix_plumed.cpp | grep -v setMPIComm > src/USER-PLUMED/fix_plumed.cpp.fix
  mv src/USER-PLUMED/fix_plumed.cpp.fix src/USER-PLUMED/fix_plumed.cpp
fi

opt=""

if [[ $(uname) == Darwin ]]; then
  # Fix the name of the PLUMED kernel on OSX
  # cmake:
  cat cmake/CMakeLists.txt | sed "s/libplumedKernel.so/libplumedKernel.dylib/" > cmake/CMakeLists.txt.fix
  mv cmake/CMakeLists.txt.fix cmake/CMakeLists.txt
  # make:
  cat lib/plumed/Makefile.lammps.runtime | sed "s/libplumedKernel.so/libplumedKernel.dylib/" > lib/plumed/Makefile.lammps.runtime.fix
  mv lib/plumed/Makefile.lammps.runtime.fix lib/plumed/Makefile.lammps.runtime
fi

# blas and lapack are not required when PLUMED is linked shared or runtime:
cat cmake/CMakeLists.txt | sed "s/ OR PKG_USER-PLUMED//" > cmake/CMakeLists.txt.fix
mv cmake/CMakeLists.txt.fix cmake/CMakeLists.txt
touch *
make -C src lib-plumed args="-p ${INSTALL_DIR} -m ${PLUMED_LinkMode}"

mkdir build
cd build
cmake -DBUILD_MPI=${BuildMPI} \
      -D FFT=FFTW3 \
      -D FFT_SINGLE=yes \
      -D FFT_FFTW_THREADS=on \
      -D FFTW3F_INCLUDE_DIR=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/include \
      -D FFTW3F_LIBRARY=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/lib/libfftw3f.a \
      -D FFTW3F_OMP_LIBRARY=/home/xhshi/hjx/software-self/lammps-simple/env/fftw338s/lib/libfftw3f_omp.a \
      -DPKG_COLLOID=yes \
      -DPKG_MANYBODY=yes \
      -DPKG_KSPACE=yes \
      -DPKG_MOLECULE=yes \
      -DPKG_RIGID=yes \
      -DPKG_OPENMP=yes \
      -DPKG_USER-PLUMED=yes \
      -DDOWNLOAD_PLUMED=no \
      -DPLUMED_MODE=${PLUMED_LinkMode} \
      $opt \
      ../cmake
#cmake -DBUILD_MPI=${BuildMPI} \
#      -DPKG_MANYBODY=yes \
#      -DPKG_KSPACE=yes \
#      -DPKG_MOLECULE=yes \
#      -DPKG_RIGID=yes \
#      -DPKG_COLLOID=yes \
#      -DPKG_ASPHERE=yes \
#      -DPKG_BODY=yes \
#      -DPKG_BOCS=yes \
#      -DPKG_BROWNIAN=yes \
#      -DPKG_CG_DNA=yes \
#      -DPKG_COLVARS=yes \
#      -DPKG_EXTRA-COMPUTE=yes \
#      -DPKG_EXTRA-DUMP=yes \
#      -DPKG_EXTRA-FIX=yes \
#      -DPKG_EXTRA-MOLECULE=yes \
#      -DPKG_EXTRA-PAIR=yes \
#      -DPKG_MC=yes \
#      -DPKG_MOLFILE=yes \
#      -DPKG_OPENMP=yes \
#      -DPKG_USER-PLUMED=yes \
#      -DDOWNLOAD_PLUMED=no \
#      -DPLUMED_MODE=${PLUMED_LinkMode} \
#      $opt \
#      ../cmake
make VERBOSE=1 -j ${Make_CPUs}


cp lmp ${PLUMED_INSTALL_DIR}/bin/lmp_simple
echo "build-lammps.sh: LAMMPS has been install as lmp in the same folder as PLUMED"
echo "build-lammps.sh: (${PLUMED_INSTALL_DIR})"
