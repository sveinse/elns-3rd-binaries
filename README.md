# ELNS 3rd party binary files

This repository contains pre-build 3rd party binaries and build & install
tools for the ELNS application. These pre-built C libraries and python modules
helps avoid tedious recompile of system libraries when working with python
virtual environments for ELNS.


## Install virtual environment with binaries

A Python virtual environment with the required C libraries injected into it
can be created by running::

    $ bin/install_venv.sh DIR packages...

`DIR` is the directory which the virtual environment shall be installed into.
`packages` represents the arguments to `pip install`. E.g. to install elns

    $ bin/install_venv.sh venv elns/

`install_venv.sh` support `--help`. If a special python version is needed, set
the `python` env var. E.g. for Windows:

    $ python="py -3.7-32" bin/install_venv.sh OPIONS...


## Prerequisite for building

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

To build the c libraries, use the following script (*):

    $ bin/build_libraries.sh

It will download and unpack into the ``build/`` directory. The
resulting libraries will be packed into ``elns-3rd-libraries*.tar.xz``
file.

If a special python version is needed, set the `python` env var. E.g. for
Windows:

    $ python="py -3.7-32" bin/build_libraries.sh

(*) Please note that these scripts are written in Bash. To be able to use these
on Windows, please use Git for Windows which includes bash or similar.


## Build Python modules

To build the python modules, use::

    $ bin/build_pymodules.sh

The resulting wheels will be places under ``*.whl``.
It will use the binary C libraries from ``elns-3rd-libraries*``
to build the modules.

If a special python version is needed, set the `python` env var. E.g. for
Windows:

    $ python="py -3.7-32" bin/build_pymodules.sh
