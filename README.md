## subversion-tools
A build script inspired by [i686-elf-tools](https://github.com/lordmilko/i686-elf-tools) that downloads subversion and its prerequisites and builds them into a self-contained pacakge.

### Required Packages (Linux)

 * binutils, gcc, g++, etc...
 * git
 * cmake
 * curl
 * python2
 * libexpat1-dev

### Required Packages (MacOSX)

 * Xcode Command Line Tools
 * cmake

### Build
```
./build_libsvn.sh [single_library]
```
Output will be in build_libsvn/lib_output
