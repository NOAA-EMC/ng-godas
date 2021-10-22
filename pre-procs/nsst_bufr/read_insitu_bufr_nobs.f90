subroutine read_insitu_bufr_nobs(infile,adate5,twindin,iobs)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  read_insitu_bufr_nobs         get the number of  sst obs from insitu_bufr file 
!   prgmmr: Xu Li          org: np22                date: 2020-11-26
!
!
! program history log:
!
!   input argument list:
!     infile   - unit from which to read BUFR data
!     adate5   - analysis/processing time
!     twindin  - input group time window (hours)
!
!   output argument list:
!     iobs     - number of obs. 
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  implicit none

! Declare passed variables
  character(len=*), intent(in):: infile
  integer, dimension(5), intent(in) :: adate5
  real   , intent(in) :: twindin
  integer, intent(out) :: iobs

! Declare local parameters
  real, parameter:: zero  = 0.0
  real, parameter:: half  = 0.5
  real, parameter:: one   = 1.0
  real, parameter:: r0_1  = 0.10
  real, parameter:: r0_15 = 0.15
  real, parameter:: r0_2  = 0.20
  real, parameter:: r0_4  = 0.40
  real, parameter:: r0_45 = 0.45
  real, parameter:: r0_6  = 0.60
  real, parameter:: r1_2  = 1.20
  real, parameter:: r1_5  = 1.50
  real, parameter:: r90   = 90.0
  real, parameter:: r360 = 360.0
  real, parameter:: r60inv = 1.0/60.0

  real, parameter:: bmiss = 1.0E11

! Declare local variables

  integer :: lunin,i
  integer :: idate,iret,k
  integer :: kx
  integer :: nmind

  integer :: ireadmg,ireadsb,klev,msub,nmsub
  integer, dimension(5) :: idate5
  character(len=8)  :: subset
  character(len=8)  :: crpid
  character(len=80) :: headr
  character(len=5)  :: cid
  real(8), dimension(7) :: hdr
  real(8), dimension(4) :: loc
  real(8), dimension(2,255) :: tpf
  real(8), dimension(2,65535) :: tpf2
  real(8) :: msst,sst
  equivalence (crpid,hdr(7))

  real :: gstime,tdiff,sstime,sstoe
  real(8) :: clath,clonh

  integer :: ikx,ibfms
  integer :: n,nread,cid_pos,ship_mod

  data headr/'YEAR MNTH DAYS HOUR MINU SELV RPID'/
  data lunin / 10 /
!**************************************************************************
  iobs = 0
  nread = 0

! get gstime: the analysis/processing time (minutes from 19000101?)
!
  call w3fs21(adate5,nmind)
  gstime=real(nmind)

! Open, then read date from bufr data
  open(lunin,file=infile,form='unformatted')
  call openbf(lunin,'IN',lunin)
  call datelen(10)
       
! READING EACH REPORT FROM BUFR
       
  do while (ireadmg(lunin,subset,idate) == 0)
     msub = nmsub(lunin)

!           case ( 'NC001001' ) ; ctyp='ships   '
!           case ( 'NC001002' ) ; ctyp='dbuoy   '
!           case ( 'NC001003' ) ; ctyp='dbuoyb  '
!           case ( 'NC001003' ) ; ctyp='mbuoy   '
!           case ( 'NC001103' ) ; ctyp='mbuoyb  '
!           case ( 'NC001004' ) ; ctyp='lcman   '
!           case ( 'NC001005' ) ; ctyp='tideg   '
!           case ( 'NC001007' ) ; ctyp='cstgd   '
!           case ( 'NC031001' ) ; ctyp='bathy   '
!           case ( 'NC031002' ) ; ctyp='tesac   '
!           case ( 'NC031003' ) ; ctyp='trkob   '

     read_loop: do while (ireadsb(lunin) == 0)
        call ufbint(lunin,hdr,7,1,iret,headr)

!          Measurement types
!             0       Ship intake
!             1       Bucket
!             2       Hull contact sensor
!             3       Reversing Thermometer
!             4       STD/CTD sensor
!             5       Mechanical BT
!             6       Expendable BT
!             7       Digital BT
!             8       Thermistor chain
!             9       Infra-red scanner
!             10      Micro-wave scanner
!             11-14   Reserved
! data headr/'YEAR MNTH DAYS HOUR MINU CLATH CLONH SELV RPID'/
!
!     Determine measurement type
!
        if ( ( trim(subset) == 'NC001003' ) .or. &            ! MBUOY
             ( trim(subset) == 'NC001004' ) .or. &            ! LCMAN
             ( trim(subset) == 'NC001001' ) ) then            ! SHIPS
           call ufbint(lunin,msst,1,1,iret,'MSST')            ! for ships, fixed buoy and lcman
           call ufbint(lunin,sst,1,1,iret,'SST1')             ! read SST
        elseif ( trim(subset) == 'NC001103' ) then            ! MBUOYB
           msst = 0.0                                         ! for mbuoyb, assign to be 0
           call ufbint(lunin,sst,1,1,iret,'SST0')
        elseif ( trim(subset) == 'NC001002' ) then            ! DBUOY
           msst = 11.0                                        ! for drifting buoy, assign to be 11
           call ufbint(lunin,sst,1,1,iret,'SST1')
        elseif ( trim(subset) == 'NC001102' ) then            ! DBUOYB
           msst = 11.0                                        ! for drifting buoyb, assign to be 11
           call ufbint(lunin,sst,1,1,iret,'SST0')
        elseif ( trim(subset) == 'NC031002' ) then            ! TESAC
           msst = 12.0                                        ! for ARGO, assign to be 12
           call ufbint(lunin,tpf2,2,65535,klev,'DBSS STMP')   ! read T_Profile
           if ( tpf2(1,1) < 5.0 ) then
              sst = tpf2(2,1)
           else
              sst = bmiss
           endif
        elseif ( trim(subset) == 'NC031001' ) then            ! BATHY
           msst = 13.0                                 ! for BATHY, assign to be 13
           call ufbint(lunin,tpf2,2,65535,klev,'DBSS STMP')   ! read T_Profile

           if ( tpf2(1,1) < 5.0 ) then
              sst = tpf2(2,1)
           else
              sst = bmiss
           endif
        elseif ( trim(subset) == 'NC031003' ) then            ! TRKOB
           msst = 14.0                                 ! for TRKOB, assign to be 14
           call ufbint(lunin,tpf,2,255,klev,'DBSS STMP')      ! read T_Profile
           if ( tpf(1,1) < 1.0 ) then
              sst = tpf(2,1)
           else
              sst = bmiss
           endif
        elseif ( trim(subset) == 'NC001005' ) then            ! TIDEG
           msst = 15.0                                 ! for TIDEG, assign to be 15
           call ufbint(lunin,sst,1,1,iret,'SST1')             ! read SST
        elseif ( trim(subset) == 'NC001007' ) then            ! CSTGD
           msst = 16.0                                 ! for CSTGD, assign to be 16
           call ufbint(lunin,sst,1,1,iret,'SST1')             ! read SST
        endif

        call ufbint(lunin,loc,4,1,iret,'CLAT CLATH CLON CLONH')
        clath=loc(1) ; if ( ibfms(loc(2)).eq.0 ) clath=loc(2)
        clonh=loc(3) ; if ( ibfms(loc(4)).eq.0 ) clonh=loc(4)

        nread = nread + 1

        if (  sst > 250.0 .and. sst < 350.0 ) then

           cid = trim(crpid)
!          Extract type, date, and location information
           if(clonh >= r360)  clonh = clonh - r360
           if(clonh <  zero)  clonh = clonh + r360

!          Check for valid latitude and longitude
           if (abs(clonh) > r360) cycle read_loop
           if (abs(clath) > r90 ) cycle read_loop

!          Extract date information.  If time outside window, skip this obs
           idate5(1) = nint(hdr(1))    !year
           idate5(2) = nint(hdr(2))    !month
           idate5(3) = nint(hdr(3))    !day
           idate5(4) = nint(hdr(4))    !hour
           idate5(5) = nint(hdr(5))    !minute

           call w3fs21(idate5,nmind)
           sstime=float(nmind)
           tdiff=(sstime-gstime)*r60inv
!          write(*,*) 'gstime,sstime,tdiff : ',gstime,sstime,tdiff
 
           if( abs(tdiff) > twindin ) cycle read_loop ! outside time window

           iobs = iobs + 1
        end if                                          ! if (  sst > 250.0 .and. sst < 350.0 ) then
     enddo read_loop
  enddo
!
!   End of bufr read loop
       
! Normal exit
1000 continue

  write(*,*) 'read_insitu_bufr,nread,iobs : ',nread,iobs

! Close unit to bufr file
1020 continue
  call closbf(lunin)

! End of routine
  return
end subroutine read_insitu_bufr_nobs
