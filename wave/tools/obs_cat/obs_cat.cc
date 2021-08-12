/*
 * (C) Copyright 2020-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 * This program uses mpi to read ioda output files in parallel and concatenate
 *  them into a single file.
 *
 * The following assumptions are made:
 * 1. the dimension concatenated across is named "nlocs". If a variable doesn't
 *    contain "nlocs" we dont care about it and skip it.
 * 2. The number of input files equals number of PEs this program is run with.
 * 3. nc attributes are ignored and not copied over.
 */

#include <sys/stat.h>
#include <mpi.h>

#include <string>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <memory>

#include "netcdf"


int main(int argc, char *argv[]) {
  // initialize MPI
  int mpi_rank, mpi_size;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &mpi_rank);
  MPI_Comm_size(MPI_COMM_WORLD, &mpi_size);
  bool root = mpi_rank == 0;


  // get command line arguments
  std::string infile, outfile;
  bool debug = false;
  for (int i = 1; i < argc; i++) {
    std::string arg = std::string(argv[i]);
    if (arg == "-i") {
      infile = std::string(argv[++i]);
    } else if (arg == "-o") {
      outfile = std::string(argv[++i]);
    } else if (arg == "-d") {
      debug = true;
    } else {
      if (root ) std::cerr << "Unknown argument: " << arg << std::endl;
      infile = "";
      break;
    }
  }
  if ( infile == "" | outfile == "" ) {
    if ( root ) {
      std::cerr << " Usage: obs_cat -i <input_prefix> -o <output_filename> (-d)"
                << std::endl;
    }
    MPI_Abort(MPI_COMM_WORLD, 1);
  }


  // for now, make sure that the # PEs == # files
  if ( root ) {
    struct stat buffer;
    std::ostringstream os;

    os << infile << "_" << std::setfill('0') << std::setw(4)
       << (mpi_size-1) << ".nc";
    bool exists = stat(os.str().c_str(), &buffer) == 0;
    os.str("");

    os << infile << "_" << std::setfill('0') << std::setw(4)
       << mpi_size << ".nc";
    bool exists_p1 = stat(os.str().c_str(), &buffer) == 0;

    if ( !exists || exists_p1 ) {
      std::cerr << "Number of PEs must equal number of input files!"
                << std::endl;
      MPI_Abort(MPI_COMM_WORLD, 1);
    }
  }
  MPI_Barrier(MPI_COMM_WORLD);


  // determine the local filename to read in.
  std::ostringstream os;
  os << infile <<"_" << std::setfill('0') << std::setw(4) << mpi_rank << ".nc";
  std::string local_filename = os.str();


  // open the file, and tell the root pe the number of locs
  netCDF::NcFile ncin(local_filename, netCDF::NcFile::read);
  unsigned int nlocs = ncin.getDim("nlocs").getSize();
  std::vector<int> p_nlocs(mpi_size);
  MPI_Gather(&nlocs, 1, MPI_UNSIGNED,
             p_nlocs.data(), 1, MPI_INT,
             0, MPI_COMM_WORLD);
  int g_nlocs = 0;  // total number of nlocs
  if ( root ) {
    for (int i=0; i < mpi_size; ++i) {
      g_nlocs += p_nlocs[i];
    }
  }


  // memory for the asynchronous mpi gathers
  std::map<std::tuple<std::string, std::string>, void*> s_bufrs;
  std::map<std::tuple<std::string, std::string>, void*> r_bufrs;
  std::vector<MPI_Request> reqs;


  // for each variable, get the data on the root pe
  auto vars = ncin.getVars(netCDF::NcGroup::Location::All);
  for (auto var_pair : vars) {
    auto var = var_pair.second;

    // is this a var we need to cat?
    bool useVar = false;
    for (netCDF::NcDim var_dim : var.getDims()) {
      if (var_dim.getName() == "nlocs") {
        useVar = true;
        break;
      }
    }
    if (!useVar) continue;
    if (root && debug) std::cout << " USING " << var.getParentGroup().getName()
                                 << "/" << var.getName() << std::endl;

    // calculate number of bytes this pe will send
    size_t dim_size = 1;
    for (auto dim : var.getDims()) {
      dim_size *= dim.getSize();
    }
    size_t s_size = 0;
    if (var.getType().getId() == netCDF::NcType::ncType::nc_STRING) {
      // process strings specially
      char * cbufr[dim_size];
      var.getVar(cbufr);
      for (size_t i = 0; i < dim_size; i++) {
        s_size += strlen(cbufr[i]) + 1;
      }
    } else {
      s_size = var.getType().getSize();
      s_size *= dim_size;
    }

    // allocate space for the send buffer
    void * s_bufr = malloc(s_size);
    s_bufrs.insert(std::make_pair(
      std::make_tuple(var.getParentGroup().getName(), var.getName()), s_bufr));

    // calculate number of bytes and offsets for receive buffer
    std::vector<int> r_size(mpi_size);
    std::vector<int> r_displ(mpi_size);
    void * r_bufr;
    if (root) {
      int r_size_total = 0;
      for (int i =0; i < mpi_size; i++) {
        r_size[i] = p_nlocs[i] * s_size/nlocs;
        r_size_total += r_size[i];
        r_displ[i] = i == 0 ? 0 : r_size[i-1] + r_displ[i-1];
      }
      r_bufr = malloc(r_size_total);
      memset(r_bufr, 0, sizeof(r_bufr));
      r_bufrs.insert(std::make_pair(
         std::make_tuple(var.getParentGroup().getName(), var.getName()),
         r_bufr));
    }

    // fill the buffer and send
    reqs.emplace_back();
    if (var.getType().getId() == netCDF::NcType::ncType::nc_STRING) {
      // process string specially
      char * cbufr[dim_size];
      var.getVar(cbufr);
      size_t idx = 0;
      for (size_t i = 0; i < dim_size; i++) {
        size_t slen = strlen(cbufr[i]) + 1;
        strncpy(reinterpret_cast<char*>(s_bufr) + idx, cbufr[i], slen);
        idx += slen;
      }
    } else {
      var.getVar(s_bufr);
    }
    MPI_Igatherv(s_bufr, s_size, MPI_BYTE,
                r_bufr, r_size.data(), r_displ.data(), MPI_BYTE,
                0, MPI_COMM_WORLD, &reqs.back());
  }

  // setup output file
  std::unique_ptr<netCDF::NcFile> ncout;
  if ( root ) {
    if (debug) std::cout << "creating output file: " << outfile << std::endl;
    ncout.reset(new netCDF::NcFile(outfile, netCDF::NcFile::replace));

    if (debug) std::cout << "creating dim: " << std::endl;
    for (auto dim : ncin.getDims()) {
      if (debug) std::cout << "  " << dim.first << std::endl;
      ncout->addDim(dim.first,
                    dim.first == "nlocs" ? g_nlocs : dim.second.getSize());
    }

    if (debug) std::cout << "creating group:" << std::endl;
    for (auto grp : ncin.getGroups()) {
      if (debug) std::cout << "  " << grp.first << std::endl;
      ncout->addGroup(grp.first);
    }

    if (debug) std::cout << "creating var:" << std::endl;
    for (auto var : ncin.getVars(netCDF::NcGroup::Location::All)) {
      if (debug) std::cout << "  " << var.second.getParentGroup().getName()
                           << "/" << var.first << std::endl;
      auto grp = ncout->getGroup(var.second.getParentGroup().getName(),
                                 netCDF::NcGroup::GroupLocation::AllGrps);
      auto v = grp.addVar(var.first, var.second.getType(),
                          var.second.getDims());
      v.setCompression(true, true, 5);
    }
  }


  // wait for all the mpi gathers to finish
  MPI_Waitall(reqs.size(), reqs.data(), MPI_STATUSES_IGNORE);

  // write out data and cleanup
  if ( root ) {
    if (debug) std::cout << "Writing data:" << std::endl;
    for (auto pair : r_bufrs) {
      if (debug) std::cout << "  " << std::get<0>(pair.first) << "/"
                           << std::get<1>(pair.first) << std::endl;
      auto grp = ncout->getGroup(std::get<0>(pair.first),
                                 netCDF::NcGroup::GroupLocation::AllGrps);
      auto var = grp.getVar(std::get<1>(pair.first));

      if (var.getType().getId() == netCDF::NcType::ncType::nc_STRING) {
        // handle strings specially
        size_t dim_size = 1;
        for (auto dim : var.getDims()) {
          dim_size *= dim.getSize();
        }
        char* cbufr[dim_size];
        size_t idx = 0;
        for (size_t i = 0; i < dim_size; i++) {
          cbufr[i] = reinterpret_cast<char*>(pair.second)+idx;
          idx += 1+strlen(reinterpret_cast<char*>(pair.second)+idx);
        }
        var.putVar(cbufr);
      } else {
        var.putVar(pair.second);
      }
      free(pair.second);
    }
    if (debug) std::cout << "Done writing out to " << outfile << std::endl;
    ncout->close();
  }

  ncin.close();
  MPI_Finalize();

  return 0;
}
