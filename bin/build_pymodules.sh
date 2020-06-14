#!/bin/bash
shopt -s nullglob

rpath () {
    (cd "$1" && pwd)
}

# dir is path to project dir
base="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$base"

# Tool version
TOOLVERSION='4'

# -- Running system
case "$(uname)" in
    *NT*)  sys=windows ;;
    *Linux*)  sys=linux ;;
    *Darwin*)
        sys=osx
        macver="$(sw_vers -productVersion)"
        case "$macver" in
            10.15.*|10.14.*|10.13.*|10.12.*|10.11.*|10.10.*|10.9.*) macrel="10_9" ;;
            10.8.*|10.7.*|10.6.*) macrel="10_6" ;;
            *) macrel="0" ;;
        esac
        ;;
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
        archive="elns-3rd-libraries-macosx_${macrel}_$(uname -m)"
        ;;
    linux)
        archive="elns-3rd-libraries-linux_$(uname -m)"
        ;;
    *)
        echo "ERROR: Don't know what to build for '$(uname)'"
        exit 1
        ;;
esac

# -- Helpers
log () {
    echo -e "\033[33m>>>>  $*\033[0m"
}

# Go to build dir
mkdir -p build
cd build


# Make fresh virtualenv for this
venv="venv"

if [[ ! -d "$venv" ]]; then
    log "Creating venv in '$venv'"
    ( set -x
      $winpty $python -m venv "$venv"
    ) || exit 1
fi
venv="$(rpath "$venv")"
python="$venv/$bindir/python"
pip="$venv/$bindir/pip"


log "Installing packages"
( set -x
  # Use this technique to upgrade pip. Calling pip directly will fail on Windows
  $winpty $python -m pip install --upgrade pip wheel
) || exit 1


# Unpack library into venv
if [[ ! -d "$venv/dist" ]]; then
    log "Unpacking '$archive.tar.xz'"
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
    log "Building $d"
    ( set -x; if [[ ! -d "$d" ]]; then
      git clone https://github.com/sveinse/pyaudio.git -b feature-channel-split $d
      fi ) || exit 1

    ( cd $d; set -ex
      $winpty $pip wheel . --no-deps
      cp -av *.whl "../../"
    ) || exit 1

}


#--- PYSNDFILE ---
build_pysndfile() {

    log "Building pysndfile"

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

    ( cd $d; set -ex
      $winpty $pip wheel . --no-deps --no-build-isolation
      cp -av *.whl "../../"
    ) || exit 1

}


#--- TWISTED ---
build_twisted() {

    log "Building twisted"

    # Download the official version
    ( set -x
      $winpty $pip download --no-deps --no-binary=:all: twisted
    ) || exit 1
    ( set -x
      tar -xf Twisted-*.tar.bz2
    ) || exit 1
    d=Twisted-*/

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


log "Complete"
cd ..
rm -rf build
