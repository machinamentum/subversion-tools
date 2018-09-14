## subversion-tools
A build script inspired by [lordmilko/i686-elf-tools](https://github.com/lordmilko/i686-elf-tools) that downloads subversion and its prerequisites and builds them into a self-contained pacakge.

force_link_glibc headers are from [wheybags/glibc_version_header](https://github.com/wheybags/glibc_version_header)

### Required Packages (Linux)

 * binutils, gcc, g++, etc...
 * git
 * cmake
 * curl
 * python2
 * docbook2x

### Required Packages (MacOSX)

 * Xcode Command Line Tools
 * cmake

### Build
```
./build_libsvn.sh [single_library]
```
Output will be in build_libsvn/lib_output
