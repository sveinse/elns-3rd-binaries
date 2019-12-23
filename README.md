# ELNS 3rd party binary files

This repository contains pre-build 3rd party binaries for the ELNS application.
The purpose is to avoid needing a full compilation environment to install the
main application by providing pre-built binaries.


## Files

 * **`elns-3rd-libraries-*.tar.xz`** - Native libries
   * `portaudio`
   * `libsndfile`
   * `libogg`  (needed by libsndfile)
   * `libflac`  (needed by libsndfile)
   * `libvorbis`  (needed by libsndfile)
   * `libvorbisenc`  (needed by libsndfile)
   * `libvorbisfile`  (needed by libsndfile)
 * **`portaudio-sln.tar.xz`** - Updated Visual Studio project for building
                                portaudio on Windows
 * **`PyAudio-*.whl`** - Custom built PyAudio from custom source
 * **`pysndfile-*.whl`** - Custom build pysndfile


## Tools

 * [bin/build_libraries.sh](bin/build_libraries.sh) - Build script to download
   and produce the binary system binaries
 * [bin/build_pymodules.sh](bin/build_pymodules.sh) - Build script to build
   the Python wheels from source. Requires a local compiler.
