#!/bin/bash

# dir is path to project dir
base="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$base"

# -- Running system
case "$(uname)" in
    *NT*)  sys=Windows ;;
    *) sys= ;;
esac

# -- Setup
if [[ "$sys" = "Windows" ]]; then
    bindir=Scripts
    winpty=winpty
    python="py -3.7"
    archive="elns-3rd-libraries-windows_win32"
else
    bindir=bin
    winpty=
    python=python3
    archive="elns-3rd-libraries-linux_$(uname -m)"
fi

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
venv="$(realpath "$venv")"
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
    if [[ "$sys" = "Windows" ]]; then
      cp -av $venv/dist/include/* $venv/Include/
      mkdir -p $venv/Libs/
      cp -av $venv/dist/lib/* $venv/Libs/
    else
      cp -av $venv/dist/include/* $venv/include/
      export LDFLAGS="-L$venv/dist/lib/"
    fi
fi
dist="$(readlink -f "$venv/dist")"


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
