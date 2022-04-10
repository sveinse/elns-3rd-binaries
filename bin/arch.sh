# Architecture helper for the build scripts
#
# Copyright (C) 2020-2022 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#

# -- Running system
case "$(uname)" in
    *NT*)
        sys=windows
        python="${python:-"py -3"}"
        bits="$($python -c'import platform;print(platform.architecture()[0])')"
        case "$bits" in
          32bit) arch='win32' ;;
          64bit) arch='x64' ;;
          *) echo "ERROR: Unknown architecture bits '$bits'"; exit 1 ;;
        esac
        ;;
    *Linux*)  sys=linux ;;
    *Darwin*)
        sys=macosx
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
bindir=bin
python="${python:-python3}"
case "$sys" in
    windows)
        #winpty=winpty
        bindir=Scripts
        archive="elns-3rd-libraries-windows_${arch}"
        ;;
    macosx)
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
    echo -e "\033[36m>>>>  $*\033[0m"
}
