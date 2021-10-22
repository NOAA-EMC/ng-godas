module iodav2

implicit none

contains
 subroutine write_iodav2(ncfile,ndatetime,nlocs,nstring,nvars,lat,lon, &
                         temp,obserror)
         
  use netcdf
  character(len=250), intent(in) :: ncfile
  character(len=40), parameter :: varname="sea_water_temperature"
  integer :: ncid, grpid
  integer :: ndatetime_varid, nlocs_varid, nstring_varid, nvars_varid, &
             temp_varid,lat_varid,lon_varid,obserror_varid,preqc_varid,&
             varmetadata_varid 
  integer, intent(in) :: ndatetime, nlocs, nstring, nvars
  integer :: dim_ndatetime,dim_nlocs,dim_nstring,dim_nvars
  real, intent(in) :: lon(nlocs),lat(nlocs),temp(nlocs),obserror(nlocs)
  
  call check( nf90_create(trim(ncfile),NF90_NETCDF4, ncid) )
  ! Create dimensions
  call check( nf90_def_dim(ncid, "ndatetime", ndatetime, dim_ndatetime) )
  call check( nf90_def_dim(ncid, "nlocs", nlocs, dim_nlocs) )
  call check( nf90_def_dim(ncid, "nstring", nstring, dim_nstring) )
  call check( nf90_def_dim(ncid, "nvars", nvars, dim_nvars) )
  ! create variables
  call check( nf90_def_var(ncid, "ndatetime", NF90_FLOAT,              &
                           dim_ndatetime, ndatetime_varid) )
  call check( nf90_def_var(ncid, "nlocs", NF90_FLOAT,                  &
                           dim_nlocs, nlocs_varid) )
  call check( nf90_def_var(ncid, "nstring", NF90_FLOAT,                & 
                           dim_nstring, nstring_varid) )
  call check( nf90_def_var(ncid, "nvars", NF90_FLOAT,                  & 
                           dim_nvars, nvars_varid) )
  ! Add global attributes
  call check( nf90_put_att(ncid, NF90_GLOBAL, "_ioda_layout","ObsGroup" ) )
  call check( nf90_put_att(ncid, NF90_GLOBAL, "_ioda_layout_version",0 ) )

  ! Create groups, variables and put data
  ! MetaData: Latitude & Longitude
  call check( nf90_def_grp(ncid, "MetaData", grpid) )
  call check( nf90_def_var(grpid, "latitude", NF90_FLOAT,              &
                           dim_nlocs, lat_varid) )
  call check( nf90_put_var(grpid, lat_varid, lat(1:nlocs)) )
  call check( nf90_def_var(grpid, "longitude", NF90_FLOAT,             &
                           dim_nlocs, lon_varid) )
  call check( nf90_put_var(grpid, lon_varid, lon(1:nlocs)) )
  ! ObsError
  call check( nf90_def_grp(ncid, "ObsError", grpid) )
  call check( nf90_def_var(grpid, "sea_water_temperature", NF90_FLOAT, &
                           dim_nlocs, obserror_varid) )
  call check( nf90_put_var(grpid, obserror_varid, obserror(1:nlocs)) )
  ! ObsValue
  call check( nf90_def_grp(ncid, "ObsValue", grpid) )
  call check( nf90_def_var(grpid, "sea_water_temperature", NF90_FLOAT, &
                           dim_nlocs, temp_varid) )
  call check( nf90_put_var(grpid, temp_varid, temp(1:nlocs)) )
  ! PreQC
  call check( nf90_def_grp(ncid, "PreQC", grpid) )
  call check( nf90_def_var(grpid, "sea_water_temperature", NF90_INT,   &
                           dim_nlocs, preqc_varid) )
  !call check( nf90_put_var(grpid, preqc_varid, preqc(1:nlocs)) )
  ! VarMetaData
  call check( nf90_def_grp(ncid, "VarMetaData", grpid) )
  call check( nf90_def_var(grpid, "variable_names", NF90_STRING,       &
                           dim_nvars, varmetadata_varid) )
  print *, trim(varname)
  !call check( nf90_put_var(grpid, varmetadata_varid,                   &
  !                         trim(varname) ) )
  ! End define mode. This tells netCDF we are done defining metadata.
  !call check( nf90_enddef(ncid) )

  ! Close the file. This frees up any internal netCDF resources
  ! associated with the file, and flushes any buffers.
  call check( nf90_close(ncid) )

  print *, "*** SUCCESS writing iodav2 file- ", trim(ncfile)
 end subroutine write_iodav2
  
 subroutine check(status)
  use netcdf
  integer, intent ( in) :: status
    
  if(status /= nf90_noerr) then 
    print *, trim(nf90_strerror(status))
    stop "Stopped"
  end if
 end subroutine check 

end module iodav2

