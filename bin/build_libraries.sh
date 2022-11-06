#!/bin/bash
# Library builder script
#
# Copyright (C) 2020-2022 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#
shopt -s nullglob

# Tool version
TOOLVERSION='5'

# Directory to place output into
dist=dist


# Path to project dir
rpath () {(cd "$1" && pwd)}
base="$(rpath "$(dirname "${BASH_SOURCE[0]}" )/..")"
cd "$base"


# Load architecture info
. "$base/bin/arch.sh"


# -- Functions
unpack() {
    name="$1"
    dir="$2"
    shift 2

    if [[ ! -d "$dir" ]]; then
        case "$name" in
            *.tar|*.tgz|*.tar.xz|*.tar.gz)
                ( set -ex
                  tar -xf "$name"
                ) || exit 1
                ;;
            *.zip)
                ( set -ex
                  unzip "$name" -d "$dir"
                ) || exit 1
                ;;
            *)
                echo "ERROR: Don't know how to unpack '$name'"
                exit 1
        esac
    fi

    # Patch the output
    while [[ "$#" -gt 0 ]]; do
        ( set -ex; cd "$dir"
          patch -p0 <"$1"
        ) || exit 1
        shift
    done
}


download() {

    url="$1"
    name="$2"
    if [[ ! "$name" ]]; then
        name="${url##*/}"
    fi
    #shift

    # Download
    if [[ ! -e "$name" ]]; then
        ( set -ex
          curl -# -L "$url" -o "$name"
        ) || exit 1
    fi
}


build() {

    dir="$1"
    shift

    # Build
    ( set -ex
      cd "$dir"
      _dist="$(cd .. && pwd)/$dist"
      PKG_CONFIG_PATH="$_dist/lib/pkgconfig" CPPFLAGS="-I$_dist/include" ./configure --prefix="$_dist" "$@"
      make -j5
      make install
    ) || exit 1

}


# Go to build dir
mkdir -p build
cd build

if [[ "$sys" = "windows" ]]; then

    # --- WINDOWS BUILD START ---

    # Set to 1 if to build with ASIO support
    with_asio=

    #
    # BUILDING PORTAUDIO
    #
    build_portaudio() {
        port=portaudio
        #branch=feature-wasapi-spatial
        #branch=v19.7.0-sveinse
        branch=master-sveinse

        ( set -ex
          rm -rf $port
          #git clone $base/../__upstream/portaudio -b $branch $port
          git clone git@github.com:sveinse/portaudio.git -b $branch $port
        ) || exit 1

        if [[ "$with_asio" ]]; then
          download https://www.steinberg.net/asiosdk asiosdk.zip
          unpack   asiosdk.zip asiosdk
          mv asiosdk/*/* asiosdk/
        fi

        # Find cmake.exe candidates
        cmk=(/c/"Program Files"*/"Microsoft Visual Studio"/*/*/*/*/*/*/CMake/Cmake/bin/cmake.exe)
        if [[ ${#cmk[@]} -eq 0 ]]; then
            echo "ERROR  Unable to find any installed cmake.exe for automatic build."
            echo "Press enter to continue..."
            read
        else
            cmk="${cmk[0]}"
            ( set -ex
              cd "portaudio"
              mkdir -p out
              cd out
              "$cmk" .. -G "Visual Studio 17 2022" -A "$arch"
              "$cmk" --build . --config Release
            ) || exit 1
        fi

        case "$arch" in
            win32) vd=x86 ;;
            x64) vd=x64 ;;
            *) echo "Unknown arch '$arch'"; exit 1 ;;
        esac

        # Extract the compiled output
        d=portaudio/out/Release
        ( set -ex
          mkdir -p $dist/include $dist/lib
          cp -av portaudio/include/*.h $dist/include/
          cp -av $d/* $dist/lib/
        ) || exit 1
    }


    #
    # LIBSNDFILE
    #
    build_libsndfile() {
        case "$arch" in
            win32) vd=win32 ;;
            x64) vd=win64 ;;
            *) echo "Unknown arch '$arch'"; exit 1 ;;
        esac

        # Get the official windows release
        d=libsndfile-1.1.0-${vd}
        download https://github.com/libsndfile/libsndfile/releases/download/1.1.0/$d.zip
        unpack   $d.zip $d
        find $d
        mkdir -p $dist/include $dist/lib
        cp -av $d/*/bin/*.dll $d/*/lib/*.lib $dist/lib
        cp -av $d/*/include/*.h $d/*/include/*.hh $dist/include/
    }


    #
    # WHAT TO BUILD
    #
    build_portaudio
    build_libsndfile


    #
    # COLLECTING DIST
    #
    ( cd "dist"; set -ex
      tar -cvJf $base/$archive.tar.xz .
    ) || exit 1

    # --- WINDOWS BUILD END ---

else

    # --- LINUX/MACOSX BUILD START ---

    #
    # BUILDING LIBSNDFILE
    #
    build_libsndfile() {
        d=libogg-1.3.4
        log "Building $d"
        download http://downloads.xiph.org/releases/ogg/$d.tar.xz
        unpack   $d.tar.xz $d ../../patches/patch-libogg-and-stdint-h.diff
        build    $d

        d=libvorbis-1.3.6
        log "Building $d"
        download http://downloads.xiph.org/releases/vorbis/$d.tar.xz
        unpack   $d.tar.xz $d
        build    $d

        d=flac-1.3.3
        log "Building $d"
        download https://ftp.osuosl.org/pub/xiph/releases/flac/$d.tar.xz
        unpack   $d.tar.xz $d
        build    $d

        d=libsndfile-1.0.28
        log "Building $d"
        download http://www.mega-nerd.com/libsndfile/files/$d.tar.gz
        unpack   $d.tar.gz $d
        build    $d
    }


    #
    # BUILDING PORTAUDIO
    #
    build_portaudio() {
        d=portaudio
        log "Building $d"

        #download http://www.portaudio.com/archives/pa_stable_v190600_20161030.tgz $d
        ( set -ex
          rm -rf $d
          git clone git@github.com:sveinse/portaudio.git -b sveinse-master $d
        ) || exit 1

        case "$sys" in
            linux)
                build $d --without-asihpi --with-alsa --without-oss
                ;;
            macosx)
                build $d --disable-mac-universal
                cp -av $d/include/pa_mac_core.h $dist/include
                ;;
        esac
    }


    #
    # WHAT TO BUILD
    #
    build_libsndfile
    build_portaudio


    #
    # MACOSX DYLIB LOAD REWRITE
    # 
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
        pip="$venv/bin/pip"

        log "Installing packages"
        ( set -ex
          # Use this technique to upgrade pip. Calling pip directly will fail on Windows
          $python -m pip install --upgrade pip wheel setuptools
          $pip install macholib
        ) || exit 1

        log "Rewriting libaray load paths"
        ( set -ex; cd $dist/lib
          $python $base/bin/macosx_dylib_loadpath.py $PWD *.so *.dylib
        ) || exit 1
    fi


    #
    # COLLECTING DIST
    #
    ( cd "dist"; set -ex
      tar -cvJf $base/$archive-complete.tar.xz .
    ) || exit 1

    ( cd "dist"; set -ex
      files=(include lib/lib*.so* lib/*.dylib)
      tar -cvJf $base/$archive.tar.xz "${files[@]}"
    ) || exit 1


    # --- LINUX/MACOSX BUILD DONE ---

fi

log "Complete"
cd ..
rm -rf build dist
