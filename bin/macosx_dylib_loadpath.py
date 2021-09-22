""" A tool to rewrite Mac OSX load path to loader_path """
# Copyright (C) 2020-2021 Svein Seldal
# Distributed under GPLv2.
#
# This tool is heavily based on code from
# https://github.com/pyinstaller/pyinstaller/blob/v3.6/PyInstaller/depend/dylib.py
#   Copyright (c) 2013-2020, PyInstaller Development Team
#   Distributed under GPL v2.

import sys
import os
import subprocess
import argparse
from macholib import util
from macholib.MachO import MachO


parser = argparse.ArgumentParser()
parser.add_argument('base', metavar="DIR")
parser.add_argument('lib', nargs='+')

opts = parser.parse_args()

# Ensure the base path ends with '/'
base = opts.base
if not base.endswith('/'):
    base += '/'

for lib in opts.lib:

    # Skip libary if not a file or a symlink
    if os.path.islink(lib) or not os.path.isfile(lib):
        continue

    # Get the relative address to the base
    rel = lib
    if rel.startswith(base):
        rel = rel.replace(base, '')

    # Determine how many directories up is the directory with shared
    # dynamic libraries. '../'
    # E.g.  ./qt4_plugins/images/ -> ./../../
    parent_dir = ''
    # Check if distname is not only base filename.
    if os.path.dirname(rel):
        parent_level = len(os.path.dirname(rel).split(os.sep))
        parent_dir = parent_level * (os.pardir + os.sep)

    count = 0

    def match_func(pth):
        """
        For system libraries is still used absolute path. It is unchanged.
        """
        global count
        # Match non system dynamic libraries.
        if not util.in_system_path(pth):
            # Use relative path to dependend dynamic libraries bases on
            # location of the executable.
            count += 1
            new = os.path.join('@loader_path', parent_dir, os.path.basename(pth))
            return new

    dll = MachO(lib)
    dll.rewriteLoadCommands(match_func)

    print(f"{count} rewrites in {lib}")

    # Write changes into file.
    # Write code is based on macholib example.
    try:
        with open(dll.filename, 'rb+') as f:
            for header in dll.headers:
                f.seek(0)
                dll.write(f)
            f.seek(0, 2)
            f.flush()
    except Exception:
        pass
