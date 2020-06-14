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
winpty=
python=python3
case "$sys" in
    windows)
        winpty=winpty
        python="py -3.7"
        archive="elns-3rd-libraries-windows_win32"
        ;;
    osx)
        archive="elns-3rd-libraries-macosx_${macrel}_$(uname -m)"
        ;;
    linux)
        archive="elns-3rd-libraries-linux_$(uname -m)"
        cat <<EOF
Required packages for building these libraries:
   apt install build-essential pkg-config patchelf libasound2-dev
EOF
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

# Directory to place output into
dist=dist


download() {

    url="$1"
    name="${url##*/}"
    shift

    # Download
    if [[ ! -e "$name" ]]; then
        ( set -ex
          curl -# -L "$url" -o "$name"
        ) || exit 1
    fi

    # Unpack
    if [[ $# -gt 0 ]]; then
        dir="$1"
        shift

        if [[ ! -d "$dir" ]]; then
            case "$name" in
                *.tar|*.tgz|*.tar.xz|*.tar.gz)
                    ( set -ex
                    tar -xf "$name"
                    ) || exit 1
                    ;;
                *.zip)
                    ( set -x
                    unzip "$name" -d "$dir"
                    ) || exit 1
                    ;;
                *)
                    echo "ERROR: Don't know how to unpack '$name'"
                    exit 1
            esac
        fi
    fi

    # Patch the output
    while [[ "$#" -gt 0 ]]; do
        ( cd "$dir"
            patch -p0 <"$1"
        )
        shift
    done
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
        download https://www.steinberg.net/sdk_downloads/asiosdk2.3.zip asiosdk

        # ASIO support
        d=$port/src/hostapi/asio/ASIOSDK
        if [[ ! -d "$d" ]]; then
            mkdir -p "$d"
            cp -av asiosdk/ASIOSDK2.3/common asiosdk/ASIOSDK2.3/host "$d"
        fi

        # Find MSBuild.exe candidates
        msb=(/c/"Program Files (x86)"/"Microsoft Visual Studio"/*/*/MSBuild/*/Bin/MSBuild.exe)
        if [[ ${#msb[@]} -eq 0 ]]; then
            echo "ERROR  Unable to find any installed MSBuild.exe for automatic build."
            echo "*****  PORTAUDIO CAN NOW BE OPENED AND BUILT IN VISUAL STUDIO"
            echo "       OPEN $PWD/portaudio/build/msvc/portaudio.sln"
            echo "Press enter to continue..."
            read
        else
            msbuild="${msb[0]}"
            for platform in win32; do  # x64
                for config in Release; do # Debug
                    ( set -ex;
                      cd "portaudio/build/msvc";
                      "$msbuild" portaudio.sln "//p:Configuration=$config" "//p:Platform=$platform"
                    )
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
            if [[ ! "$x64" ]]; then
                mkdir -p $dist/include $dist/lib
                cp -av portaudio/include/portaudio.h $dist/include/
                cp -av $d/portaudio.dll $dist/lib/
                cp -av $d/portaudio_*.lib $dist/lib/portaudio.lib
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
            if [[ "$x64" ]]; then
                mkdir -p $dist/include $dist/lib
                cp -av portaudio/include/portaudio.h $dist/include/
                cp -av $d/portaudio.dll $d/portaudio_*.lib $dist/lib/
                cp -av $d/portaudio_*.lib $dist/lib/portaudio.lib
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

        # Get the official windows release
        d=libsndfile-1.0.28-w32
        download http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.28-w32.zip $d
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
        cp -av $d/libsndfile32bit.dll $dist/lib/

        # Generate the libsndfile.lib from the dll:
        ( set -ex; cd $dist/lib
          $winpty $python $base/bin/win_dll2lib.py libsndfile32bit.dll sndfile.lib
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

    # --- LINUX/OSX BUILD START ---

    #
    # BUILDING LIBSNDFILE
    #
    build_libsndfile() {
        d=libogg-1.3.4
        log "Building $d"
        download http://downloads.xiph.org/releases/ogg/$d.tar.xz $d ../../patches/patch-libogg-and-stdint-h.diff
        build    $d

        d=libvorbis-1.3.6
        log "Building $d"
        download http://downloads.xiph.org/releases/vorbis/$d.tar.xz $d
        build    $d

        d=flac-1.3.3
        log "Building $d"
        download https://ftp.osuosl.org/pub/xiph/releases/flac/$d.tar.xz $d
        build    $d

        d=libsndfile-1.0.28
        log "Building $d"
        download http://www.mega-nerd.com/libsndfile/files/$d.tar.gz $d
        build    $d
    }


    #
    # BUILDING PORTAUDIO
    #
    build_portaudio() {
        d=portaudio
        log "Building $d"
        download http://www.portaudio.com/archives/pa_stable_v190600_20161030.tgz $d
        case "$sys" in
            linux)
                build $d --without-asihpi --with-alsa --without-oss
                ;;
            osx)
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
    # OSX DYLIB LOAD REWRITE
    # 
    if [[ "$sys" = "osx" ]]; then
        venv="venv-osx"

        # Make fresh virtualenv for this
        if [[ ! -d "$venv" ]]; then
            log "Creating venv in '$venv'"
            ( set -x
            $winpty $python -m venv "$venv"
            ) || exit 1
        fi
        venv="$(rpath "$venv")"
        python="$venv/bin/python"
        pip="$venv/bin/pip"

        log "Installing packages"
        ( set -x
          # Use this technique to upgrade pip. Calling pip directly will fail on Windows
          $python -m pip install --upgrade pip wheel
          $pip install macholib
        ) || exit 1

        log "Rewriting libaray load paths"
        ( set -ex; cd $dist/lib
          $python $base/bin/osx_dylib_loadpath.py $PWD *.so *.dylib
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


    # --- LINUX/OSX BUILD DONE ---

fi

log "Complete"
cd ..
rm -rf build
