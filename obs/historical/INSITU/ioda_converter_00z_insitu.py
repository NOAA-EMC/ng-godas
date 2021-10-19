import argparse
import numpy as np
import xarray as xr
import netCDF4 as nc
from datetime import datetime, timedelta

################################################################################
def rd_ncdf(ncin):
   ds = xr.open_dataset(ncin)

   times      = ds['time@MetaData'][:]
   lon        = ds['longitude@MetaData'][:]
   lat        = ds['latitude@MetaData'][:]
   datetime   = ds['datetime@MetaData'][:]
   swt_ObsVal = ds['sea_water_temperature@ObsValue'][:]
   swt_ObsErr = ds['sea_water_temperature@ObsError'][:]
   swt_PreQC  = ds['sea_water_temperature@PreQC'][:]
   sws_ObsVal = ds['sea_water_salinity@ObsValue'][:]
   sws_ObsErr = ds['sea_water_salinity@ObsError'][:]
   sws_PreQC  = ds['sea_water_salinity@PreQC'][:]
   depth      = ds['depth@MetaData'][:]
   rec_num    = ds['record_number@MetaData'][:]
   var_name   = ds['variable_names@VarMetaData'][:]

   ds.close()
   return times,lon,lat,datetime,swt_ObsVal,swt_ObsErr,swt_PreQC,sws_ObsVal,sws_ObsErr,sws_PreQC,depth,rec_num,var_name

def wr_ncdf(ncout,cut_dtg,nlocs,time_00_all,lon_00_all,lat_00_all,datetime_00_all,swt_ObsVal_00_all,swt_ObsErr_00_all,swt_PreQC_00_all,sws_ObsVal_00_all,sws_ObsErr_00_all,sws_PreQC_00_all,depth_00_all,rec_num_00_all,var_names):
    ds = nc.Dataset(ncout, 'w', format='NETCDF4')

    nvars     = ds.createDimension('nvars', 2)
    nlocs     = ds.createDimension('nlocs', nlocs)
    nstring   = ds.createDimension('nstring', 50)
    ndatetime = ds.createDimension('ndatetime', 20)
    
    swt_ObsVal = ds.createVariable('sea_water_temperature@ObsValue', 'f4', ('nlocs',))
    swt_ObsErr = ds.createVariable('sea_water_temperature@ObsError', 'f4', ('nlocs',))
    swt_PreQC  = ds.createVariable('sea_water_temperature@PreQC', 'int32', ('nlocs',))
    sws_ObsVal = ds.createVariable('sea_water_salinity@ObsValue', 'f4', ('nlocs',))
    sws_ObsErr = ds.createVariable('sea_water_salinity@ObsError', 'f4', ('nlocs',))
    sws_PreQC  = ds.createVariable('sea_water_salinity@ObsPreQC', 'int32', ('nlocs',))
    times      = ds.createVariable('time@MetaData', 'f4', ('nlocs',))
    lat        = ds.createVariable('latitude@MetaData', 'f4', ('nlocs',))
    lon        = ds.createVariable('longitude@MetaData', 'f4', ('nlocs',))
    depth      = ds.createVariable('depth@MetaData', 'f4', ('nlocs',))
    datetime   = ds.createVariable('datetime@MetaData', 'c', ('nlocs','ndatetime'))
    rec_num    = ds.createVariable('record_number@MetaData', 'int32', ('nlocs',))
    var_name   = ds.createVariable('variable_names@VarMetaData', 'c', ('nvars','nstring'))
    #nvars=2
    print(len(time_00_all), len(lon_00_all))

    times[:]      = time_00_all
    lon[:]        = lon_00_all
    lat[:]        = lat_00_all
    StringType_dt = "S{0:d}".format(20)
    s_dt = np.array(datetime_00_all, StringType_dt)
    datetime_all=nc.stringtochar(s_dt)
    datetime[:,:] = datetime_all[:,:]
    swt_ObsVal[:] = swt_ObsVal_00_all
    swt_ObsErr[:] = swt_ObsErr_00_all
    swt_PreQC[:]  = swt_PreQC_00_all
    sws_ObsVal[:] = sws_ObsVal_00_all
    sws_ObsErr[:] = sws_ObsErr_00_all
    sws_PreQC[:]  = sws_PreQC_00_all
    depth[:]      = depth_00_all
    rec_num[:]    = rec_num_00_all
    StringType = "S{0:d}".format(50)
    s = np.array(var_names, StringType)
    vname=nc.stringtochar(s)
    var_name[:,:]   = vname[:,:] 

    ds.nvars = np.size(nvars)
    ds.nlocs = np.size(nlocs)
    ds.odb_version = 1
    ds.date_time = cut_dtg #2015030100
    ds.close()
    return ncout

#######################################################################

def main():

   parser = argparse.ArgumentParser(
        description=(
            'Read insitu WOD IODA formatted data centered at 12z and convert'
            ' to a IODA formatted output file centered at 00z.')
   )
   required = parser.add_argument_group(title='required arguments')
   required.add_argument(
       '-idir', '--input_dir',
       help="name of insitu WOD IODA 12z input file",
       type=str, nargs='+', required=True)
   required.add_argument(
       '-d', '--date',
       help="base date for the center of the window",
       metavar='YYYYMMDDHH',type=str,required=True)
   required.add_argument(
       '-out', '--output_file',
       help="name of the insitu WOD IODA 00z file",
       type=str, required=True)
   args = parser.parse_args()

   #wdir='/work/noaa/ng-godas/spaturi/WOD_insitu/'

   ####
   #print(args.input[0])
   #cut_dtg = args.input[0].split("/")[-1].split(".")[0].split("_")[-1]
   cut_dtg = args.date
   #print(cut_dtg)
   basedate = datetime.strptime(cut_dtg, '%Y%m%d%H')
   prv_dtg  = basedate + timedelta(days=-1)
   #print("prv_dtg= ", prv_dtg)
   #print(args.input_dir[0])
   ncfile = args.input_dir[0] + '/' + prv_dtg.strftime('%Y') + '/' + prv_dtg.strftime('%Y%m%d') + '/'+ 'insitu_wod_' + prv_dtg.strftime('%Y%m%d') + '.nc'
   #ncfile=wdir+'insitu_wod_20150228.nc'
   print("Reading: " + ncfile)

   [times,lon,lat,dttime,swt_ObsVal,swt_ObsErr,swt_PreQC,sws_ObsVal,sws_ObsErr,sws_PreQC,depth,rec_num,var_name] = rd_ncdf(ncfile)


   I = np.where(times >= 0.0)
   times_00      = times[I] - 12.0
   lon_00        = lon[I]
   lat_00        = lat[I]
   datetime_00   = dttime[I]
   swt_ObsVal_00 = swt_ObsVal[I]
   swt_ObsErr_00 = swt_ObsErr[I]
   swt_PreQC_00  = swt_PreQC[I]
   sws_ObsVal_00 = sws_ObsVal[I]
   sws_ObsErr_00 = sws_ObsErr[I]
   sws_PreQC_00  = sws_PreQC[I]
   depth_00      = depth[I]
   rec_num_00    = rec_num[I]
   var_name_00   = var_name

   ####
   ncfile1 = args.input_dir[0] + '/' + cut_dtg[0:4] + '/' + cut_dtg[0:8] + '/' + 'insitu_wod_' + basedate.strftime('%Y%m%d') + '.nc'
   #ncfile1=wdir+'insitu_wod_20150301.nc'
   print("Reading: " + ncfile1)

   [times1,lon1,lat1,dttime1,swt_ObsVal1,swt_ObsErr1,swt_PreQC1,sws_ObsVal1,sws_ObsErr1,sws_PreQC1,depth1,rec_num1,var_name1] = rd_ncdf(ncfile1)


   I1 = np.where(times1 < 12.0)
   times1_00      = times1[I1]
   lon1_00        = lon1[I1]
   lat1_00        = lat1[I1]
   datetime1_00   = dttime1[I1]
   swt_ObsVal1_00 = swt_ObsVal1[I1]
   swt_ObsErr1_00 = swt_ObsErr1[I1]
   swt_PreQC1_00  = swt_PreQC1[I1]
   sws_ObsVal1_00 = sws_ObsVal1[I1]
   sws_ObsErr1_00 = sws_ObsErr1[I1]
   sws_PreQC1_00  = sws_PreQC1[I1]
   depth1_00      = depth1[I1]
   rec_num1_00    = rec_num1[I1]
   var_name1_00   = var_name1

   ###
   time_00_all=[]
   lon_00_all=[]
   lat_00_all=[]
   datetime_00_all=[]
   swt_ObsVal_00_all=[]
   swt_ObsErr_00_all=[]
   swt_PreQC_00_all=[]
   sws_ObsVal_00_all=[]
   sws_ObsErr_00_all=[]
   sws_PreQC_00_all=[]
   depth_00_all=[]
   rec_num_00_all=[]

   time_00_all=np.append(times_00, times1_00)
   lon_00_all=np.append(lon_00, lon1_00)
   lat_00_all=np.append(lat_00, lat1_00)
   datetime_00_all=np.append(datetime_00, datetime1_00)
   swt_ObsVal_00_all=np.append(swt_ObsVal_00, swt_ObsVal1_00)
   swt_ObsErr_00_all=np.append(swt_ObsErr_00, swt_ObsErr1_00)
   swt_PreQC_00_all=np.append(swt_PreQC_00, swt_PreQC1_00)
   sws_ObsVal_00_all=np.append(sws_ObsVal_00, sws_ObsVal1_00)
   sws_ObsErr_00_all=np.append(sws_ObsErr_00, sws_ObsErr1_00)
   sws_PreQC_00_all=np.append(sws_PreQC_00, sws_PreQC1_00)
   depth_00_all=np.append(depth_00, depth1_00)
   rec_num_00_all=np.append(rec_num_00, rec_num1_00)
   
   print(len(time_00_all))
   print("Writing NC File..")
   ncOUT = args.output_file #wdir+'../ioda-v1/insitu/insitu_wod_20150301.nc'

   wr_ncdf(ncOUT,np.int(cut_dtg),np.sum( [np.size(I),np.size(I1)] ),time_00_all,lon_00_all,lat_00_all,datetime_00_all,swt_ObsVal_00_all,swt_ObsErr_00_all,swt_PreQC_00_all,sws_ObsVal_00_all,sws_ObsErr_00_all,sws_PreQC_00_all,depth_00_all,rec_num_00_all,var_name)

if __name__ == '__main__':
    main()
