#!/bin/bash
# Common functions for building ELNS binaries


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


clear() {
    for f in "$@"; do
        ( set -ex
          rm -rf "$f" 2>/dev/null
          mkdir -p "$f"
        ) || exit 1
    done
}


tardir() {
    ( set -ex; cd "$1"
      tar -cvJf "$base/$2.tar.xz" .
    ) || exit 1
}


unpack_lib() {
    ( set -ex
      mkdir -p "$1"
      tar -C "$1" -xf "$base/$2-"*"-${suffix}.tar.xz"
    ) || exit 1
}


prep_pybuild() {
    case "$sys" in
        windows)
            cp -av $1/include/* $venv/Include/
            ;;
        macosx)
            cp -av $1/include/* $venv/include/
            export LDFLAGS="-L$1/lib/"
            ;;
        linux)
            cp -av $1/include/* $venv/include/
            export LDFLAGS="-L$1/lib/"
            ;;
    esac
}


find_cmake() {
    _cmake=(/c/"Program Files"*/"Microsoft Visual Studio"/*/*/*/*/*/*/CMake/Cmake/bin/cmake.exe)
    if [[ ${#_cmake[@]} -eq 0 ]]; then
        echo "ERROR  Unable to find any installed cmake.exe for build."
        echo "Press enter to continue..."
        read
        exit 1
    else
        cmake="${_cmake[0]}"
    fi
}
