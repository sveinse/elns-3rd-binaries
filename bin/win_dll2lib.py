""" A crude tool to generate a .lib from a .dll file """
# Copyright (C) 2020-2022 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#

import os
import sys
import subprocess
import tempfile
import re
import argparse
import glob

# Paths
vcvars_glob=r'C:/Program Files*/Microsoft Visual Studio/*/*/VC/Auxiliary/Build/'

# Bat script to convert DLL to a DEF file input
dumpbin = r'''
CALL "{path}"
@ECHO on
DUMPBIN /exports "%1" >"%2"
'''

# Bat script to convert parsed DEF to LIB
libbat = r'''
CALL "{path}"
@ECHO on
LIB /DEF:"%1" /OUT:"%2" /MACHINE:{arch}
'''

# Rudimentary argument checking
print(sys.argv)
if len(sys.argv) < 3:
    raise Exception("Too few arguments")

parser = argparse.ArgumentParser()
parser.add_argument('--arch', default='x86', choices=['win32', 'x64'])
parser.add_argument('infile', metavar="DLL")
parser.add_argument('outfile', metavar="LIB")
opts = parser.parse_args()

# Get the file
infile = opts.infile
deffile = infile.replace('.dll', '.def')
outfile = opts.outfile
expfile = outfile.replace('.lib', '.exp')

# Ensure the input exists
if not os.path.exists(infile):
    raise FileNotFoundError(infile)

# Get the architecture parameters
if opts.arch == 'win32':
    vcvars = 'vcvars32.bat'
    arch = 'X86'
elif opts.arch == 'x64':
    vcvars = 'vcvars64.bat'
    arch = 'X64'
else:
    raise Exception(f"Unknown architecture '{opts.arch}'")

# Find Visual C++
candidates = glob.glob(vcvars_glob + vcvars)
if not candidates:
    raise FileNotFoundError(f"Could not find '{vcvars_glob + vcvars}'. Is Visual Studio installed?")
vcvars_path = candidates[0]
print(f"Found '{vcvars_path}'")

# Create a temp working directory
with tempfile.TemporaryDirectory() as tmpdirname:

    # Write the temp bat script for dumping the DLL file and run it
    bat = os.path.join(tmpdirname, 'run.bat')
    with open(bat, 'w') as f:
        f.write(dumpbin.format(path=vcvars_path))
    subprocess.check_call([bat, infile, deffile])

    # Parse the output from dumpbin and make it into a file with
    # EXPORTS
    # method names...
    out = 'EXPORTS\n'
    with open(deffile, 'r') as f:
        mode = 'header'
        n = 0
        i = 1
        for line in f:
            n += 1
            l = line.strip()
            s = re.split(r'\s+', l)

            if len(s) != 4:
                continue
            try:
                ordinal = int(s[0])
            except ValueError:
                continue
            if ordinal != i:
                continue

            i += 1
            out += s[3] + '\n'

    # Write the def file
    print(deffile)
    with open(deffile, 'w') as f:
        f.write(out)

    # Write the temp bat script for generating the LIB file and run it
    bat = os.path.join(tmpdirname, 'run.bat')
    with open(bat, 'w') as f:
        f.write(libbat.format(path=vcvars_path, arch=arch))
    subprocess.check_call([bat, deffile, outfile])

    # Remove the temporary def file
    os.remove(deffile)
    os.remove(expfile)
