subroutine read_insitu_bufr(infile,adate5,twindin,nobs,tz,alat,alon,depth,atim,ictype,stn_id,obserr,zob_dbuoy)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  read_insitu_bufr         read sst obs from insitu_bufr file 
!   prgmmr: Xu Li          org: np22                date: 2020-11-26
!
! abstract:  This routine reads conventional tz data from insitu_bufr
!
! program history log:
!   2021-02-15  Li      - modify to handle bufr ships, restricted (nc001101) and
!                         unrestricted (NC001113), and bufr land based lcman
!                         (nc001104)
!   2021-09-09  Li      - modify to handle bufr ships, restricted
!   (nc001013,shipsu)
!
!   input argument list:
!     infile    - unit from which to read BUFR data
!     adate5    - analysis/processing time
!     twindin   - input group time window (hours)
!     nobs      - number of obs. 
!     zob_dbuoy - dbuoy depth
!
!   output argument list:
!     tz       - array of observations 
!     alat     - latitude array of observations 
!     alon     - longitude array of observations 
!     depth    - depth array of observations 
!     atim     - time (diff in hours: obstim - anatim) array of observations 
!     ictype   - platform type 
!     stn_id   - station ID (character*8)
!     obserr   - obs. error
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use insitu_info, only: n_comps,n_scripps,n_triton,n_3mdiscus,cid_mbuoy,cid_mbuoyb,n_ship,ship
  use insitu_info, only: mbuoy_info,mbuoyb_info,read_ship_info

  implicit none

! Declare passed variables
  character(len=*), intent(in):: infile
  integer, dimension(5), intent(in) :: adate5
  real   , intent(in) :: twindin,zob_dbuoy
  integer, intent(in) :: nobs
  real, dimension(nobs), intent(out):: tz,alat,alon,depth,atim,obserr
  integer, dimension(nobs), intent(out):: ictype
  character(len=8), dimension(nobs), intent(out):: stn_id

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

  integer :: lunin,i,iobs
  integer :: idate,iret,k
  integer :: kx
  integer :: nmind
  integer :: idomsfc,isflg

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
  real :: dlat_earth_deg,dlon_earth_deg
  real :: zob,tref,dtw,dtc,tz_tr
  real(8) :: clath,clonh

  integer :: ikx,ibfms
  integer :: n,nread,cid_pos,ship_mod

  data headr/'YEAR MNTH DAYS HOUR MINU SELV RPID'/
  data lunin / 10 /
!**************************************************************************
  iobs = 0
  nread = 0

! Create moored buoy station ID
  call mbuoy_info

! Create moored buoy station ID for mbuoyb with 7-digit station ID
  call mbuoyb_info

! Create ships info(ID, Depth & Instrument)
  call read_ship_info
!
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
!           case ( 'NC001013' ) ; ctyp='ships   '
!           case ( 'NC001101' ) ; ctyp='ships   '
!           case ( 'NC001113' ) ; ctyp='ships   '
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
             ( trim(subset) == 'NC001001' ) .or. &            ! SHIPS
             ( trim(subset) == 'NC001101' ) .or. &            ! bufr SHIPS, restricted
             ( trim(subset) == 'NC001013' ) .or. &            ! bufr SHIPS,unrestricted
             ( trim(subset) == 'NC001113' ) ) then            ! bufr SHIPS,unrestricted
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

           dlon_earth_deg = clonh
           dlat_earth_deg = clath

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
 
!      
!          determine platform (ships, dbuoy, fbuoy or lcman and so on) dependent zob and obs. error
!
           if ( trim(subset) == 'NC001001' .or. trim(subset) == 'NC001101' .or. &
                trim(subset) == 'NC001013' .or. trim(subset) == 'NC001113' )    then          ! SHIPS
              ship_mod = 0
              do n = 1, n_ship
                 if ( crpid == trim(ship%id(n)) ) then
                    ship_mod = 1
                    zob = ship%depth(n)
                    if ( trim(ship%sensor(n)) == 'BU' ) then
                       kx = 181
                       sstoe = 0.75
                    elseif ( trim(ship%sensor(n)) == 'C' ) then
                       kx = 182
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'HC' ) then
                       kx = 183
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'BTT' ) then
                       kx = 184
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'HT' ) then
                       kx = 185
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'RAD' ) then
                       kx = 186
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'TT' ) then
                       kx = 187
                       sstoe = one
                    elseif ( trim(ship%sensor(n)) == 'OT' ) then
                       kx = 188
                       sstoe = one
                    else
                       kx = 189
                       sstoe = 2.0
                    endif
                 endif
              enddo

              if ( ship_mod == 0 ) then
                 if ( msst == 2.0 ) then                                  ! positive or zero bucket
                    kx = 181
                    sstoe = 0.75
                    zob = one
                 elseif ( msst == zero .or. msst == one ) then            ! positive/negative/zero intake
                    kx = 182
                    sstoe = one
                    zob = 3.0
                 else
                    kx = 189
                    sstoe = 2.0
                    zob = 2.5
                 endif
              endif


           elseif ( trim(subset) == 'NC001002'  ) then                        ! DBUOY

              cid_pos = 0

              do n = 1, n_3mdiscus
                 if ( cid == cid_mbuoy(n) ) then
                    cid_pos = n
                 endif
              enddo
 
              if ( cid_pos >= 1 .and. cid_pos <= n_comps ) then                ! COMPS moored buoy

                 zob = r1_2
                 kx = 192
                 sstoe = 0.75

              elseif ( cid_pos > n_scripps .and. cid_pos <= n_triton ) then    ! Triton buoy
 
                 zob = r1_5
                 kx = 194
                 sstoe = half
 
              elseif ( cid_pos == 0 ) then
 
                 if ( cid(3:3) == '5' .or. cid(3:3) == '6' .or. cid(3:3) == '7' .or. cid(3:3) == '8' .or. cid(3:3) == '9' ) then
!                   zob = r0_2
                    zob = zob_dbuoy
                    kx = 190
                    sstoe = half
                 elseif ( cid(3:3) == '0' .or. cid(3:3) == '1' .or. cid(3:3) == '2' .or. cid(3:3) == '3' .or. cid(3:3) == '4') then
                    zob = one
                    kx = 191
                    sstoe = half
                 endif

              endif

           elseif ( trim(subset) == 'NC001102'  ) then                           ! DBUOYB
!             zob = r0_2
              zob = zob_dbuoy
              kx = 190
              sstoe = half
           elseif ( trim(subset) == 'NC001003' ) then                            ! MBUOY

              cid_pos = 0

              do n = 1, n_3mdiscus
                 if ( cid == cid_mbuoy(n) ) then
                    cid_pos = n
                 endif
              enddo

              if ( cid_pos >= 1 .and. cid_pos <= n_comps ) then                  ! COMPS moored buoy
                 zob = r1_2
                 kx = 192
                 sstoe = 0.75
              elseif ( cid_pos > n_comps .and. cid_pos <= n_scripps ) then       ! SCRIPPS moored buoy
                 zob = r0_45
                 kx = 193
                 sstoe = 0.75
              elseif ( cid_pos > n_scripps .and. cid_pos <= n_triton ) then      ! Triton buoy
                 zob = r1_5
                 kx = 194
                 sstoe = half
              elseif ( cid_pos > n_triton .and. cid_pos <= n_3mdiscus ) then     ! Moored buoy with 3-m discus
                 zob = r0_6
                 kx = 195
                 sstoe = 0.75
              elseif ( cid_pos == 0 ) then                                       ! All other moored buoys (usually with 1-m observation depth)
                 zob = one
                 kx = 196
                 sstoe = 0.75
              endif

           elseif ( trim(subset) == 'NC001103' ) then                            ! MBUOYB

              cid_pos = 0

              do n = 1, n_3mdiscus
                 if ( cid == cid_mbuoyb(n) ) then
                    cid_pos = n
                 endif
              enddo

              if ( cid_pos >= 1 .and. cid_pos <= n_comps ) then                  ! COMPS moored buoyb
                 zob = r1_2
                 kx = 192
                 sstoe = 0.75
              elseif ( cid_pos > n_comps .and. cid_pos <= n_scripps ) then       ! SCRIPPS moored buoyb
                 zob = r0_45
                 kx = 193
                 sstoe = 0.75
              elseif ( cid_pos > n_scripps .and. cid_pos <= n_triton ) then      ! Triton buoyb
                 zob = r1_5
                 kx = 194
                 sstoe = half
              elseif ( cid_pos > n_triton .and. cid_pos <= n_3mdiscus ) then     ! Moored buoyb with 3-m discus
                 zob = r0_6
                 kx = 195
                 sstoe = 0.75
              elseif ( cid_pos == 0 ) then                                       ! All other moored buoysb (usually with 1-m observation depth)
                 zob = one
                 kx = 196
                 sstoe = 0.75
              endif

           elseif ( trim(subset) == 'NC001004' .or. trim(subset) == 'NC001104' .or. trim(subset) == 'NC031003' .or. &    ! LCMAN, TRKOB
                    trim(subset) == 'NC001005' .or. trim(subset) == 'NC001007' ) then    ! TIDEG, CSTGD
              zob = one
              kx = 197
              sstoe = one
           elseif ( trim(subset) == 'NC031002' ) then                            ! TESAC/ARGO
              if (  tpf(1,1) >= one .and.  tpf(1,1) < 5.0 ) then
                 zob = tpf(1,1)
              elseif (  tpf(1,1) >= zero .and. tpf(1,1) < one ) then
                 zob = one
              endif
              kx = 198
              sstoe = one
           elseif ( trim(subset) == 'NC031001' ) then                            ! BATHY
              if (  tpf(1,1) >= one .and.  tpf(1,1) < 5.0 ) then
                 zob = tpf(1,1)
              elseif (  tpf(1,1) >= zero .and. tpf(1,1) < one ) then
                 zob = one
              endif
              kx = 199
              sstoe = half
           endif

           if( abs(tdiff) > twindin ) cycle read_loop ! outside time window

           iobs = iobs + 1
           tz(iobs)     = sst
           alat(iobs)   = dlat_earth_deg
           alon(iobs)   = dlon_earth_deg
           depth(iobs)  = zob
           atim(iobs)   = tdiff
           ictype(iobs) = kx
           stn_id(iobs) = crpid
           obserr(iobs) = sstoe
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
end subroutine read_insitu_bufr
