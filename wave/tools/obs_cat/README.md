How to compile on Orion:
source wave/config/machine.machine.orion.intel

mpiicc -o obs_cat.x ../ng-godas/wave/tools/obs_cat/obs_cat.cc -I/work/noaa/da/grubin/opt/modules/intel-2020/impi-2020/netcdf/4.7.4/include -L/work/noaa/da/grubin/opt/modules/intel-2020/impi-2020/netcdf/4.7.4/lib -lnetcdf_c++4 -lnetcdf

cp obs_cat.x to your soca build/bin folder
