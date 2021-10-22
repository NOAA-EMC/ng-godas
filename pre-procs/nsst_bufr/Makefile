SHELL=  /bin/sh

CMD= read_write_insitu_bufr.x

OBJS = insitu_info.o read_insitu_bufr_nobs.o read_insitu_bufr.o iodav2.o read_write_insitu_bufr.o

FCOMP = ifort

FFLAGS = -assume byterecl -warn all -implicitnone -g -traceback  -convert big_endian -fp-model strict 

build: $(CMD)

$(CMD): $(OBJS)
	$(FCOMP) $(FFLAGS)  $(NETCDF_INCLUDE) -o $(CMD) $(OBJS) $(NETCDF_LDFLAGS_F) $(BACIO_LIB4) $(W3NCO_LIB4) $(BUFR_d)

insitu_info.o:  insitu_info.f90
	$(FCOMP) $(FFLAGS) -c insitu_info.f90

read_insitu_bufr_nobs.o:  read_insitu_bufr_nobs.f90
	$(FCOMP) $(FFLAGS) -c read_insitu_bufr_nobs.f90

read_insitu_bufr.o:  read_insitu_bufr.f90
	$(FCOMP) $(FFLAGS) -c read_insitu_bufr.f90

iodav2.o:  iodav2.f90
	$(FCOMP) $(FFLAGS) $(NETCDF_INCLUDE) -c iodav2.f90

read_write_insitu_bufr.o:  read_write_insitu_bufr.f90
	$(FCOMP) $(FFLAGS) -c read_write_insitu_bufr.f90

