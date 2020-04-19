""" A crude tool to generate a .lib from a .dll file """

import os
import sys
import subprocess
import tempfile
import re

# Bat script to convert DLL to a DEF file input
dumpbin = r'''
CALL "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"
@ECHO on
DUMPBIN /exports "%1" >"%2"
'''


# Bat script to convert parsed DEF to LIB
libbat = r'''
CALL "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"
@ECHO on
LIB /DEF:"%1" /OUT:"%2" /MACHINE:X86
'''

# Rudimentary argument checking
print(sys.argv)
if len(sys.argv) < 3:
    raise Exception("Too few arguments")

# Get the file
infile = sys.argv[1]
deffile = infile.replace('.dll', '.def')
outfile = sys.argv[2]
expfile = outfile.replace('.lib', '.exp')

# Ensure the input exists
if not os.path.exists(infile):
    raise FileNotFoundError(infile)

# Create a temp working directory
with tempfile.TemporaryDirectory() as tmpdirname:

    # Write the temp bat script for dumping the DLL file and run it
    bat = os.path.join(tmpdirname, 'run.bat')
    with open(bat, 'w') as f:
        f.write(dumpbin)
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
        f.write(libbat)
    subprocess.check_call([bat, deffile, outfile])

    # Remove the temporary def file
    os.remove(deffile)
    os.remove(expfile)
