#!/bin/bash
# Python virtual environment installer
#
# Copyright (C) 2020 Svein Seldal
# This source code is licensed under the MIT license found in the LICENSE file
# in the root directory for this source tree.
#

rpath () {(cd "$1" && pwd)}

# path to project dir
base="$(rpath "$(dirname "${BASH_SOURCE[0]}" )/..")"

# Tool version
TOOLVERSION='4'

# -- Load architecture info
. "$base/bin/arch.sh"

# -- Help
usage () {
    ME="$(basename "${BASH_SOURCE[0]}")"
    cat <<EOF
$ME -- Virtual environment installer v${TOOLVERSION}
(C) 2020 Svein Seldal <sveinse@seldal.com>

  Install a virtual environment and inject external C libraries
  into it using packages from prebuild binary files.

Usage: $ME [OPTIONS] DIRECTORY [--] PIP_INSTALL_OPTIONS...

Options:
  --help         Print this help
  --bare         Only install the venv
  --delete       Delete DIRECTORY before installing
  --nolibs       Do not install binary libraries
  --noupgrade    Do not run pip update

EOF
}

# Default options
bare=
delete=
upgrade=1
nolibs=

# -- Parse arguments
unset first_arg
args=()
while [[ "$#" -gt 0 ]]
do
    case "$1" in
        --help)
            usage
            exit 1
            ;;
        --bare)       bare=1 ;;
        --delete)     delete=1 ;;
        --nolibs)     nolibs=1 ;;
        --noupgrade)  upgrade= ;;
        --)
            shift
            break
            ;;
        -*)
            if [[ "$first_arg" ]]; then
                args+=("$1")
            else
                log "Invalid option '$1'"
                exit 1
            fi
            ;;
        *)
            first_arg=1
            args+=("$1")
            ;;
    esac
    shift
done
# Catch up any args after -- as well
while [[ "$#" -gt 0 ]]; do
    args+=("$1")
    shift
done

# -- Check remaining arg count
if [[ ${#args[@]} -lt 1 ]]; then
    usage
    log "Too few arguments"
    exit 1
fi
[[ ! "$bare" ]] && [[ ${#args[@]} -lt 2 ]] && {
    usage
    log "Too few arguments"
    exit 1
}

# -- Get the argument
venv="${args[0]}"
unset args[0]

# Work on file globs from now on
shopt -s nullglob


# -- Delete the old venv
if [[ "$delete" ]]; then
    if [[ -d "$venv" ]]; then
        log "Deleting existing venv"
        ( set -ex
          rm -rf "$venv"
        ) || exit 1
    fi
fi


# -- Create the venv
if [[ ! -d "$venv" ]]; then
    log "Creating venv in '$venv'"
    ( set -ex
      $winpty $python -m venv "$venv"
    ) || exit 1
fi
python="$venv/$bindir/python"
pip="$venv/$bindir/pip"


# -- Upgrade pip and wheel
if [[ "$upgrade" ]]; then
    log "Upgrading pip and wheel"
    ( set -ex
      # Use this technique to upgrade pip. Calling pip directly will fail on Windows
      $winpty $python -m pip install --upgrade pip wheel
    ) || exit 1
fi


# -- Only install bare venv
[[ "$bare" ]] && exit 0


# -- Run pip
log "Running 'pip install ${args[@]}'"
mkdir -p "$base/dist/"
( set -ex
  $winpty $pip install --find-links=$base/ "${args[@]}" "${extrapkg[@]}"
) || exit 1


# -- Get the Python lib directory
pylib="$($python -c 'import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())')"
log "Python lib dir: $pylib"
mkdir -p "$pylib"


# -- Do not install the binary libraries
[[ "$nolibs" ]] && exit 0


# -- Install the binaries
if [[ "$archive" ]]; then
    log "Unpacking binary '$archive.tar.xz'"

    # Setup tempdir for our binaries
    archtmp="$(mktemp -d)"
    deltmp() {
        rm -rf "$archtmp"
    }
    trap deltmp 0

    # Unpack the binaries
    ( set -ex
      tar -C "$archtmp" -xf "$base/$archive.tar.xz"
    ) || exit 1
fi


if [[ "$sys" = "windows" ]]; then

    # --- WINDOWS INSTALL START ---

    log "Installing libs in venv"
    files=($archtmp/lib/*.dll)
    for f in "${files[@]}"; do
        fn="${f##*/}"
        case "$fn" in
            libsndfile*.dll)
                dp="$pylib/pysndfile/"
                ;;
            *)
                dp="$pylib"
                ;;
        esac
        cp -av "$f" "$dp"
    done

    # --- WINDOWS INSTALL DONE ---

elif [[ "$sys" = "linux" ]]; then

    # --- LINUX INSTALL START ---

    # Copy the so from the binary dist and set the proper rpath when doing so
    log "Installing libs in venv"
    files=($archtmp/lib/*.so*)
    rpath=()
    for f in "${files[@]}"; do
        fn="${f##*/}"
        cp -av "$f" "$pylib"
        rpath+=("$pylib/$fn")
    done

    # Set rpath on the wheels as well
    log "Setting rpath on installed wheels"
    rpath+=($pylib/pysndfile/*.so $pylib/_portaudio*.so)
    for f in "${rpath[@]}"; do
        [[ -f "$f" ]] && (
            set -ex
            patchelf --set-rpath "$pylib" "$f"
        )
    done

    # --- LINUX INSTALL DONE ---

elif [[ "$sys" = "macosx" ]]; then

    # --- MACOSX INSTALL START ---

    # Copy the so from the binary dist and set the proper rpath when doing so
    log "Installing libs in venv"
    files=($archtmp/lib/*.dylib $archtmp/lib/*.so)
    repair=()
    for f in "${files[@]}"; do
        fn="${f##*/}"
        cp -av "$f" "$pylib"
        repair+=("$pylib/$fn")
    done

    log "Rewriting library references"
    repair+=($pylib/pysndfile/*.so $pylib/_portaudio*.so)
    ( set -ex
      $pip install macholib
      $python $base/bin/macosx_dylib_loadpath.py "$pylib" "${repair[@]}"
    ) || exit 1

    # --- MACOSX INSTALL DONE ---

fi

log "Completed"
