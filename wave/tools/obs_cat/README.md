How to compile on Orion:
source wave/config/machine.machine.orion.intel

cd to the PATH of your soca build/bin

mpiicc -o obs_cat.x /YOUR_PATH_OF_n-godas_repo/ng-godas/wave/tools/obs_cat/obs_cat.cc -I/work/noaa/da/jedipara/opt/modules/intel-2020.2/impi-2020.2/netcdf/4.7.4/include -L/work/noaa/da/jedipara/opt/modules/intel-2020.2/impi-2020.2/netcdf/4.7.4/lib -lnetcdf_c++4 -lnetcdf
