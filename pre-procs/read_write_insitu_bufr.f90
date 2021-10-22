program read_write_insitu_bufr

use iodav2, only: write_iodav2

implicit none
!integer, parameter :: IUNIT=10
character(len=250) :: infile,ncfile
integer, dimension(5) :: adate5
real :: twindin, zob_dbuoy
integer :: i,nobs
integer, parameter :: ndatetime=20,nstring=50,nvars=1
!lat/lon and time arrays
real,    allocatable, dimension(:) :: alat,alon,zob,atim,temp,obserror,depth
character(len=8), allocatable, dimension(:) :: stn_id
integer, allocatable, dimension(:)          :: ictype

infile='/scratch1/NCEPDEV/global/glopara/dump/gdas.20210212/12/gdas.t12z.nsstbufr'
print *, "infile = ", trim(infile)
twindin=6.0
adate5(1)=2021
adate5(2)=2
adate5(3)=12
adate5(4)=12
adate5(5)=0
print *, adate5, twindin
call read_insitu_bufr_nobs(trim(infile),adate5,twindin,nobs)
!write(*,'(a,I9)') 'sstcnv, nobs : ',nobs
zob_dbuoy=0.20

allocate( alat(nobs),alon(nobs),zob(nobs),atim(nobs),temp(nobs),obserror(nobs),depth(nobs) ) 
allocate( stn_id(nobs),ictype(nobs) )
call read_insitu_bufr(infile,adate5,twindin,nobs,temp,alat,alon,depth,atim,ictype,stn_id,obserror,zob_dbuoy)
write(20,*) (temp(i), alat(i), alon(i), depth(i), obserror(i),i=1,nobs)
print *, "Done"

ncfile='nsst_bufr_20210221.nc'
print *, ncfile
call write_iodav2(ncfile,ndatetime,nobs,nstring,nvars,alat,alon,temp,obserror)

deallocate(alat,alon,zob,atim,temp,obserror,depth,stn_id,ictype)

end
