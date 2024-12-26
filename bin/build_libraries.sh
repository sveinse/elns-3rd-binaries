#!/bin/bash
# Library builder script
#
# Copyright (C) 2020-2024 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#
shopt -s nullglob

# Tool version
TOOLVERSION='6'

# Directory to place output into
dist=dist

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

# Set to 1 if to build with ASIO support
with_asio=


#
# BUILDING PORTAUDIO
# ========================================
# Required by pyaudio
#

prepare_portaudio() {
    padir="$1"

    # url=https://github.com/sveinse/portaudio.git
    # branch=v19.7.0-sveinse
    # branch=master-sveinse
    # branch=feature-wasapi-spatial

    # Use the official portaudio repo
    url=https://github.com/PortAudio/portaudio.git
    branch=master

    ( set -ex
      rm -rf $padir
      git clone $url -b $branch $padir
      cd $padir
      # Custom patches
      git apply $base/patches/portaudio-exports.diff
    ) || exit 1

    # Extract the version
    v="$(grep -oP '(?<=PortAudio VERSION )([\d.]*)' "$padir/CMakeLists.txt")-$(cd $padir && git log -1 --pretty=format:%h)"

    if [[ "$with_asio" ]]; then
      download https://www.steinberg.net/asiosdk asiosdk.zip
      asioopts="-DPA_USE_ASIO=ON -DASIO_SDK_ZIP_PATH="$base/build/asiosdk.zip""
    fi
}


if [[ "$sys" = "windows" ]]; then

    build_portaudio() {

        log "Building PortAudio"
        clear $dist

        padir=portaudio
        prepare_portaudio portaudio

        # Configure and build
        find_cmake  # Sets $cmake
        release=RelWithDebInfo
        ( set -ex
          cd $padir
          "$cmake" \
            -G "Visual Studio 17 2022" -A "$arch" \
            -DCMAKE_BUILD_TYPE=$release \
            -DPA_BUILD_SHARED_LIBS=ON \
            $asioopts \
            -S . -B build
          "$cmake" \
            --build build --config $release
        ) || exit 1

        # Extract the compiled output
        d=$padir/build/$release
        ( set -ex
          mkdir -p $dist/include $dist/lib
          cp -av portaudio/include/*.h $dist/include/
          cp -av $d/* $dist/lib/
          rm $dist/lib/*.pdb $dist/lib/*.exp
        ) || exit 1
        tardir $dist "portaudio-${v}-${suffix}"

        log "PortAudio version $v complete"
    }

else  # Linux/MacOSX

    build_portaudio() {

        log "Building PortAudio"
        clear $dist

        padir=portaudio
        prepare_portaudio $padir

        case "$sys" in
            linux)
                build $padir --without-asihpi --with-alsa --without-oss --disable-static
                ;;
            macosx)
                build $padir --disable-mac-universal
                cp -av $padir/include/pa_mac_core.h $dist/include
                ;;
        esac
        tardir $dist "portaudio-${v}-${suffix}"
    }

    # --- LINUX/MACOSX BUILD DONE ---

fi


#
# BUILDING LIBSNDFILE
# =======================================
# Required by pysndfile
#

if [[ "$sys" = "windows" ]]; then

    build_libsndfile() {

        log "Collecting Libsndfile"

        clear $dist
        case "$arch" in
            win32) vd=win32 ;;
            x64) vd=win64 ;;
            *) echo "Unknown arch '$arch'"; exit 1 ;;
        esac

        # Get the official windows release
        v=1.2.2
        d=libsndfile-${v}-${vd}
        download https://github.com/libsndfile/libsndfile/releases/download/${v}/$d.zip
        unpack   $d.zip $d

        # Extract the gathered files
        ( set -ex
          mkdir -p $dist/include $dist/lib
          cp -av $d/*/bin/*.dll $d/*/lib/*.lib $dist/lib
          cp -av $d/*/include/*.h $d/*/include/*.hh $dist/include/
        ) || exit 1
        tardir $dist "libsndfile-${v}-${suffix}"

        log "Libsndfile version $v complete"
    }

else  # Linux/MacOSX

    build_libsndfile() {

        log "Building libsndfile"

        d=libogg-1.3.5
        log "Building $d"
        download http://downloads.xiph.org/releases/ogg/$d.tar.xz
        unpack   $d.tar.xz $d $base/patches/patch-libogg-and-stdint-h.diff
        build    $d --disable-static

        d=libvorbis-1.3.7
        log "Building $d"
        download http://downloads.xiph.org/releases/vorbis/$d.tar.xz
        unpack   $d.tar.xz $d
        build    $d --disable-static

        d=flac-1.4.3
        log "Building $d"
        download https://ftp.osuosl.org/pub/xiph/releases/flac/$d.tar.xz
        unpack   $d.tar.xz $d
        build    $d --disable-static

        d=opus-1.5.2
        log "Building $d"
        download https://ftp.osuosl.org/pub/xiph/releases/opus/$d.tar.gz
        unpack   $d.tar.gz $d
        build    $d --disable-static

        v=1.2.2
        d=libsndfile-$v
        log "Building $d"
        download https://github.com/libsndfile/libsndfile/releases/download/$v/$d.tar.xz
        unpack   $d.tar.xz $d
        build    $d --disable-static

        rm -rf $dist/share
        tardir $dist "libsndfile-${v}-${suffix}"

        log "Libsndfile complete"
    }

fi


#
# MACOSX DYLIB LOAD REWRITE
#
skip() {
    if [[ "$sys" = "macosx" ]]; then
        venv="venv-macosx"

        # Make fresh virtualenv for this
        if [[ ! -d "$venv" ]]; then
            log "Creating venv in '$venv'"
            ( set -ex
              $python -m venv "$venv"
            ) || exit 1
        fi
        venv="$(rpath "$venv")"
        python="$venv/bin/python"
        pip="$python -m pip"

        log "Installing packages"
        ( set -ex
          $pip install --upgrade pip wheel setuptools
          $pip install macholib
        ) || exit 1

        log "Rewriting libaray load paths"
        ( set -ex; cd $dist/lib
          $python $base/bin/macosx_dylib_loadpath.py $PWD *.so *.dylib
        ) || exit 1
    fi
}


#
# WHAT TO BUILD
#
build_portaudio
build_libsndfile


log "Complete"
cd ..
rm -rf "$build" "$dist"
