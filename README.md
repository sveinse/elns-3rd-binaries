# ELNS 3rd party binary files

This repository contains pre-build 3rd party binaries for the ELNS application by
providing pre-built C libraries and python modules. The purpose is to avoid
needing a full compilation environment to install the python virtual environment
application by providing pre-built binaries.

There are two types of modules: The C libraries and the Python modules. To build
any python modules that requires C compiling some additional tools are required:

  * Please consult https://wiki.python.org/moin/WindowsCompilers to see what
    version of Windows compiler is needed.
    - The current 3.6 and 3.7 Python needs Microsoft Build Tools for Visual
      Studio 2017 (VS 14.0),
      https://www.visualstudio.com/downloads/#build-tools-for-visual-studio-2017
    - Make sure the "VC++ 2015.3 v14.00 (v140) for desktop" is enabled
    - Perhaps "rc.exe" is missing when building with pip/python:
      https://stackoverflow.com/questions/14372706/visual-studio-cant-build-due-to-rc-exe

  * Some libraries, like portaudio, requires full Visual Studio to be built

**2020-06 update**: On windows the `build_libaries.sh` compilation succeeded by
                    only installing:

  * **Visual Studio Community 2019**, option *"Desktop development with C++"*.
    Includes `MSVC v142 - VS 2019 C++ x64/x86`, `Windows 10 SDK (10.0.18362.0)`


## Build C libraries

To build the c libraries, use the following script:

    $ bin/build_libraries.sh

It will download and unpack into the ``build/`` directory. The
resulting libraries will be packed into ``elns-3rd-libraries*.tar.xz``
file.


## Build Python modules

To build the python modules, use::

    $ bin/build_pymodules.sh

The resulting wheels will be places under ``*.whl``.
It will use the binary C libraries from ``elns-3rd-libraries*``
to build the modules.


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
