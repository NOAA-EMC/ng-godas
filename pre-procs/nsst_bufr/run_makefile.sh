#!bin/bash

module load intel/18.0.5.274
# Loding nceplibs modules
module use -a /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles
module load netcdf/4.7.0
module load hdf5/1.10.5
module load bacio/2.0.2
module load nemsio/2.2.3
module load w3nco/2.0.6
module load sp/2.0.2
export BUFR_d=/scratch2/NCEPDEV/nwprod/NCEPLIBS/compilers/intel/18.0.5.274/lib/libbufr_v11.3.0_d_64.a
export NETCDF_INCLUDE="-I${NETCDF}/include"
export NETCDF_LDFLAGS_F="-L${NETCDF}/lib -lnetcdf -lnetcdff -L${HDF5}/lib -lhdf5 -lhdf5_fortran"

make -f Makefile

err=$?
if [ $err -ne 0 ]; then
  echo ERROR BUILDING read_write_insitu_bufr.x
  exit 2
fi

