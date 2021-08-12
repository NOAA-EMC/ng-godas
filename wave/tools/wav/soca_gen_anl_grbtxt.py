#!/usr/bin/env python
import netCDF4
import numpy as np
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
import sys
import yaml


class WavState(object):

    def __init__(self, fname=[], model=[], output=[]):
        self.fname = fname
        self.model = model
        self.output = output

    def readfile(self):
        # Read wave ana state. Right now SWH only
        ncf = netCDF4.Dataset(self.fname,'r')
        if ( (self.model=="jedi-ww3") ):
            self.swh = np.squeeze(ncf.variables['hs'][:])
        else:
            sys.exit("Read not implemented for "+self.model)
        ncf.close()

    def writefile(self):
        # Write a w3_upstr readable file
        nx = self.swh.shape[1]
        ny = self.swh.shape[0] 
        #
        file1 = open(self.output,"w")
        file1.write(str(nx)+" "+str(ny)+" \n")
        for j in range(0, ny):
          for i in range(0,nx):
            L = (ny-1)-j
            K = i
            #print(L,K)
            file1.write(str(max(0.0,self.swh[L][K]))+" \n")            
        file1.close()

def main():
  desc = "A wav utility script."
  parser = ArgumentParser(
           description=desc,
           formatter_class=ArgumentDefaultsHelpFormatter)
  parser.add_argument(
        '-m', '--model', help='jedi-ww3',
        type=str, default='jedi-ww3', required=False)
  #parser.add_argument(
  #      '-f', '--filename', help='Name of wav model background file',
  #      type=str, required=True)
  parser.add_argument(
        '-i', '--anafilename', help='Name of wave analysis file',
        type=str, required=True)
  #parser.add_argument(
  #      '-a', '--action', help='model2soca, soca2model',
  #      type=str, default='model2soca', required=False)
  parser.add_argument(
        '-o', '--output', help='Output file name',
        type=str, default='anl.grbtxt', required=False)

  args = parser.parse_args()

  ana = WavState(fname=args.anafilename,
                 model=args.model,
                 output=args.output)

  ana.readfile()
  ana.writefile() 

if __name__ == '__main__':
    main()
