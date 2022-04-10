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

    #
    # BUILDING PORTAUDIO
    #
    build_portaudio() {
        port=portaudio

        ( set -ex
          rm -rf $port
          #git clone https://git.assembla.com/portaudio.git $port
          #git clone git@github.com:sveinse/portaudio.git -bfeature-wasapi-spatial $port
          git clone git@github.com:sveinse/portaudio.git -b sveinse-master $port
        ) || exit 1

        #download http://www.portaudio.com/archives/pa_stable_v190600_20161030.tgz $port
        #download https://www.steinberg.net/sdk_downloads/asiosdk2.3.zip asiosdk
        download https://www.steinberg.net/asiosdk asiosdk.zip
        unpack   asiosdk.zip asiosdk

        # ASIO support
        d=$port/src/hostapi/asio/ASIOSDK
        if [[ ! -d "$d" ]]; then
            ( set -ex
              mkdir -p "$d"
              cp -av asiosdk/*/common asiosdk/*/host "$d"
            ) || exit 1
        fi

        # Find MSBuild.exe candidates
        msb=(/c/"Program Files"*/"Microsoft Visual Studio"/*/*/MSBuild/*/Bin/MSBuild.exe)
        if [[ ${#msb[@]} -eq 0 ]]; then
            echo "ERROR  Unable to find any installed MSBuild.exe for automatic build."
            echo "*****  PORTAUDIO CAN NOW BE OPENED AND BUILT IN VISUAL STUDIO"
            echo "       OPEN $PWD/portaudio/build/msvc/portaudio.sln"
            echo "Press enter to continue..."
            read
        else
            msbuild="${msb[0]}"
            for platform in "$arch"; do
                for config in Release; do # Debug
                    ( set -ex
                      cd "portaudio/build/msvc";
                      "$msbuild" portaudio.sln "//p:Configuration=$config" "//p:Platform=$platform"
                    ) || exit 1
                done
            done
        fi

        if [[ -d portaudio/build/msvc/Win32/Release ]]; then
            # Extract the win32 output
            d=portaudio/build/msvc/Win32/Release
            #rm -rf win32
            #mkdir -p win32
            #cp -av portaudio/include/portaudio.h $d/portaudio.dll $d/portaudio_*.lib win32/
            #tar -C win32 -cvJf ../portaudio-v190600-win_win32.tar.xz .
            #rm -rf win32
            if [[ "$arch" = "win32" ]]; then
                ( set -ex
                  mkdir -p $dist/include $dist/lib
                  cp -av portaudio/include/*.h $dist/include/
                  cp -av $d/portaudio.dll $dist/lib/
                  cp -av $d/portaudio_*.lib $dist/lib/portaudio.lib
                ) || exit 1
            fi
        fi

        if [[ -d portaudio/build/msvc/x64/Release ]]; then
            # Extract the x64 output
            d=portaudio/build/msvc/x64/Release
            #rm -rf x64
            #mkdir -p x64
            #cp -av portaudio/include/portaudio.h $d/portaudio.dll $d/portaudio_*.lib x64/
            #tar -C x64 -cvJf ../portaudio-v190600-win_x64.tar.xz .
            #rm -rf x64
            if [[ "$arch" = "x64" ]]; then
                ( set -ex
                  mkdir -p $dist/include $dist/lib
                  cp -av portaudio/include/*.h $dist/include/
                  cp -av $d/portaudio.dll $dist/lib/
                  cp -av $d/portaudio_*.lib $dist/lib/portaudio.lib
                ) || exit 1
            fi
        fi
    }


    #
    # LIBSNDFILE
    #
    build_libsndfile() {
        # Get the sources for reference and licenses
        #download http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.28.tar.gz libsndfile-1.0.28
        #download https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.2.tar.xz libogg-1.3.2
        #download https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.5.tar.xz libvorbis-1.3.5
        #download https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.3.2.tar.xz flac-1.3.2

        case "$arch" in
            win32) vd=w32; fd=32bit ;;
            x64) vd=w64; fd=64bit ;;
            *) echo "Unknown arch '$arch'"; exit 1 ;;
        esac

        # Get the official windows release
        d=libsndfile-1.0.28-${vd}
        download http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.28-${vd}.zip
        unpack   libsndfile-1.0.28-${vd}.zip $d
        mkdir -p $dist/include
        #cp -av $d/bin/*.dll $d/lib/*.lib $dist/lib
        cp -av $d/include/*.h $d/include/*.hh $dist/include/
        #mv $dist/lib/libsndfile-1.lib $dist/lib/sndfile.lib
        #mv $dist/lib/libsndfile-1.dll $dist/lib/sndfile.dll

        # Get the non-official windows build that includes flac and friends
        d=libsndfile-binaries
        if [[ ! -d $d ]]; then
            ( set -ex
              git clone https://github.com/bastibe/libsndfile-binaries.git $d
              cd $d
              git checkout 84cb164928f17c7ca0c1e5c40342c20ce2b90e8c
            ) || exit 1
        fi
        mkdir -p $dist/lib
        cp -av $d/libsndfile${fd}.dll $dist/lib/

        # Generate the libsndfile.lib from the dll:
        ( set -ex; cd $dist/lib
          $winpty $python $base/bin/win_dll2lib.py --arch $arch libsndfile${fd}.dll sndfile.lib
        ) || exit 1
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
rm -rf build
