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
 * automake
 * autoconf
 * libtool

> NOTE: Homebrew's version of libtool is required. It might be installed as glibtool to not conflict with Apple's. This is fine and will still work.

### Build
Options:
 * Any of _expat utf8proc sqlite zlib openssl apr apr-util serf subversion_ - builds only the specified packages, does not handle depency management between them.
 * clean - removes build directories and the output directory to enable rebuilding/reconfiguring packages from source.
 * single_library - creates a unified library named "libsvn.so" (or "libsvn.dylib" on macOS) containing the libraries built by all packages.

```
./build_libsvn.sh [options]
```
Output will be in build_libsvn/lib_output
