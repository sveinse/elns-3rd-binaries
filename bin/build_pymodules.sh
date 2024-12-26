#!/bin/bash
# Python module builder
#
# Copyright (C) 2020-2024 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#
shopt -s nullglob

# Tool version
TOOLVERSION='6'

# Path to project dir
rpath () {(cd "$1" && pwd)}
base="$(rpath "$(dirname "${BASH_SOURCE[0]}" )/..")"
cd "$base"

# Load architecture info and functions
. "$base/bin/arch.sh"
. "$base/bin/functions.sh"

# Go to build dir
[[ "$1" ]] && build="$1" || build=build
mkdir -p "$build"
cd "$build"

# Location of env
venv=venv

# Make fresh virtualenv for this
if [[ ! -d "$venv" ]]; then
    log "Creating venv in '$venv'"
    ( set -ex
      $winpty $python -m venv "$venv"
      $winpty "$venv/$bindir/python" -m pip install --upgrade pip wheel setuptools
    ) || exit 1
fi
venv="$(rpath "$venv")"
python="$winpty $venv/$bindir/python"
pip="$python -m pip"


mkdir -p "$venv/dist"
dist="$(rpath "$venv/dist")"  # Won't work if path doesn't exist


#--- PYAUDIO ---
build_pyaudio() {

    log "Building PyAudio"

    clear $dist
    unpack_lib "$dist" portaudio
    prep_pybuild "$dist"

    # Download the official version and patch it
    v=0.2.14
    d=PyAudio-$v/
    ( set -ex
      $pip download --no-deps --no-binary=:all: --no-build-isolation pyaudio==$v
    ) || exit 1
    ( set -ex
      tar -xf PyAudio-$v.tar.gz
      cd $d
      patch -p1 < $base/patches/pyaudio-$v-s1.diff
    ) || exit 1

    # # Download the official version from git
    # log "Building $d"
    # ( set -ex; if [[ ! -d "$d" ]]; then
    #   git clone $url -b $branch $d
    #   fi
    # ) || exit 1

    # # Get our locally modified version
    # d=pyaudio
    # ( set -ex; rm -rf $d
    #   cp -a $base/../__upstream/PyAudio-0.2.14 $d
    # ) || exit 1

    ( set -ex; cd $d;
      rm -rf dist
      $python setup.py build_ext -L "$venv/dist/lib" -l portaudio
      $python setup.py bdist_wheel
      out=(dist/*.whl)
      [[ ${#out[@]} -eq 0 ]] && exit 1
      cp -av "${out[@]}" "$base"
    ) || exit 1

    log "PyAudio complete"
}


#--- PYSNDFILE ---
build_pysndfile() {

    log "Building pysndfile"

    clear $dist
    unpack_lib "$dist" libsndfile
    prep_pybuild "$dist"

    ( set -ex
      $pip install numpy cython
    ) || exit 1

    # # Download the official version
    # ( set -ex
    #   $pip download --no-deps --no-binary=:all: --no-build-isolation pysndfile==1.4.6
    # ) || exit 1
    # ( set -ex
    #   tar -xf pysndfile-*.tar.gz
    # ) || exit 1
    # d=pysndfile-1.*/

    # Get the version from source
    # At the time of writing, the official 1.4.6 version doesn't build on Windows,
    # but the development 1.4.7 version does.
    d=pysndfile
    ( set -x; if [[ ! -d $d ]]; then
     git clone https://forge-2.ircam.fr/roebel/pysndfile.git $d
     fi ) || exit 1

    ( set -ex; cd $d;
      rm -rf dist
      export SNDFILE_INSTALL_DIR="$venv/dist"
      $python setup.py build_ext
      $python setup.py bdist_wheel
      out=(dist/*.whl)
      [[ ${#out[@]} -eq 0 ]] && exit 1
      cp -av "${out[@]}" "$base"
    ) || exit 1

}


#
# WHAT TO BUILD
#
build_pyaudio
build_pysndfile


log "Complete"
cd ..
rm -rf "$build" "$dist"
