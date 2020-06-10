#!/bin/bash

rpath () {
    python -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}

# dir is path to project dir
base="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$base"

# Tool version
TOOLVERSION='4'

# -- Running system
case "$(uname)" in
    *NT*)  sys=windows ;;
    *Darwin*)  sys=osx ;;
    *Linux*)  sys=linux ;;
    *) sys= ;;
esac

# -- Setup
bindir=bin
winpty=
python=python3
case "$sys" in
    windows)
        bindir=Scripts
        winpty=winpty
        python="py -3.7"
        archive="elns-3rd-libraries-windows_win32"
        ;;
    osx)
        macver="10_14"
        archive="elns-3rd-libraries-macosx_${macver}_$(uname -m)"
        ;;
    linux)
        archive="elns-3rd-libraries-linux_$(uname -m)"
        ;;
    *)
        echo "ERROR: Don't know what to build for '$(uname)'"
        exit 1
        ;;
esac

# Go to build dir
mkdir -p build
cd build


# Make fresh virtualenv for this
venv="venv"

if [[ ! -d "$venv" ]]; then
    echo "Creating venv in '$venv'"
    ( set -x
      $winpty $python -m venv "$venv"
    ) || exit 1
fi
venv="$(rpath "$venv")"
python="$venv/$bindir/python"
pip="$venv/$bindir/pip"


echo "Installing packages"
( set -x
  # Use this technique to upgrade pip. Calling pip directly will fail on Windows
  $winpty $python -m pip install --upgrade pip wheel
) || exit 1


# Unpack library into venv
if [[ ! -d "$venv/dist" ]]; then
    echo "Unpacking '$archive.tar.xz'"
    mkdir -p "$venv/dist"
    tar -C "$venv/dist" -xf "../$archive.tar.xz"
    case "$sys" in
        windows)
            cp -av $venv/dist/include/* $venv/Include/
            mkdir -p $venv/Libs/
            cp -av $venv/dist/lib/* $venv/Libs/
            ;;
        osx)
            cp -av $venv/dist/include/* $venv/include/
            export LDFLAGS="-L$venv/dist/lib/"
            ;;
        linux)
            cp -av $venv/dist/include/* $venv/include/
            export LDFLAGS="-L$venv/dist/lib/"
            ;;
    esac
fi
dist="$(rpath "$venv/dist")"


#------------------------------------------------------------------------------


#--- PYAUDIO ---
build_pyaudio() {

    # Get our modified version
    d=pyaudio
    ( set -x; if [[ ! -d "$d" ]]; then
      git clone https://github.com/sveinse/pyaudio.git -b feature-channel-split $d
      fi ) || exit 1

    echo "Building pyaudio"
    ( cd $d; set -ex
      $winpty $pip wheel . --no-deps
      cp -av *.whl "../../"
    ) || exit 1

}


#--- PYSNDFILE ---
build_pysndfile() {
    ( set -x
      $winpty $pip install numpy cython
    ) || exit 1

    # Download the official version
    ( set -x;
      $winpty $pip download --no-deps --no-binary=:all: --no-build-isolation pysndfile
    ) || exit 1
    ( set -x;
      tar -xf pysndfile-*.tar.gz
    ) || exit 1
    d=pysndfile-1.*/

    # Get the version from source
    #d=pysndfile
    #( set -x; if [[ ! -d $d ]]; then
    #  git clone https://github.com/roebel/pysndfile.git $d
    #  fi ) || exit 1

    echo "Building pysndfile"
    ( cd $d; set -ex
      $winpty $pip wheel . --no-deps --no-build-isolation
      cp -av *.whl "../../"
    ) || exit 1

}


#--- TWISTED ---
build_twisted() {

    # Download the official version
    ( set -x
      $winpty $pip download --no-deps --no-binary=:all: twisted
    ) || exit 1
    ( set -x
      tar -xf Twisted-*.tar.bz2
    ) || exit 1
    d=Twisted-*/

    echo "Building twisted"
    ( cd $d; set -ex
      $winpty $pip wheel . --no-deps;
      cp -av *.whl "../../"
    ) || exit 1

}


#
# WHAT TO BUILD
#
build_pyaudio
build_pysndfile

# Twisted doesn't require compiler any more, cached build from pypi is ok
#build_twisted
