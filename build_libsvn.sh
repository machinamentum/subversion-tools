#!/bin/bash

SUBVERSION_VERSION=1.10.3
APR_VERSION=1.6.5
APR_UTIL_VERSION=1.6.1
ZLIB_VERSION=1.2.11
SERF_VERSION=1.3.9
OPENSSL_VERSION=1.1.0i
SCONS_VERSION=2.3.0
SQLITE_VERSION=autoconf-3240000

FORCE_GLIBC=2.5

GLOBAL_CFLAGS="-fPIC"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac
echo ${machine}

if type wget > /dev/null ; then
  dl_command="wget"
else
  dl_command="curl"
fi

set -ex

args=$@

function checkArg {
	name=$1
	if [[ $args == *"$name"* ]]
	then
		to_build="$to_build $name"
	fi
}

function main {
	mkdir -p build_libsvn
	cd build_libsvn

	echoColor "Downloading sources"
	downloadAndExtract "subversion" $SUBVERSION_VERSION "http://mirrors.koehn.com/apache/subversion/subversion-$SUBVERSION_VERSION.tar.gz"
	downloadAndExtract "apr" $APR_VERSION "http://www.trieuvan.com/apache//apr/apr-$APR_VERSION.tar.gz"
	downloadAndExtract "apr-util" $APR_UTIL_VERSION "http://www.trieuvan.com/apache//apr/apr-util-$APR_UTIL_VERSION.tar.gz"
	downloadAndExtract "zlib" $ZLIB_VERSION "http://www.zlib.net/zlib-$ZLIB_VERSION.tar.gz"
	downloadAndExtract "serf" $SERF_VERSION "https://www.apache.org/dist/serf/serf-$SERF_VERSION.tar.bz2"
	downloadAndExtract "openssl" $OPENSSL_VERSION "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
	downloadAndExtract "sqlite" $SQLITE_VERSION "https://www.sqlite.org/2018/sqlite-$SQLITE_VERSION.tar.gz"

	# clone the Julia repo for utf8proc because github releases dont provide a URL to a true zip file of the source code (AFAICT)
	gitClone utf8proc https://github.com/JuliaStrings/utf8proc.git
	gitClone expat https://github.com/libexpat/libexpat.git

	# fixup expat because it doesnt have it's configure tree at its root
	if [ ! -d expat-git-temp ]
	then
		mkdir -p expat-git-temp
		mv ./expat-git/* ./expat-git-temp/.
		cp -r ./expat-git-temp/expat/* expat-git/.
	fi

	mkdir -p lib_output
	my_path=`pwd`
	lib_path=$my_path/lib_output/lib
	include_path=$my_path/lib_output/include
	if [ $machine != "Mac" ]
	then
		GLOBAL_CFLAGS="$GLOBAL_CFLAGS -include $my_path/../force_link_glibc_$FORCE_GLIBC.h"
	fi

	if [[ $args == *"clean"* ]]
	then
		rm -rf lib_output
		rm -rf build_expat
		rm -rf build_utf8proc
		rm -rf build_sqlite
		rm -rf build_zlib
		rm -rf build_openssl
		rm -rf build_serf
		rm -rf build_subversion
	fi

	BUILD_ALL="expat utf8proc sqlite zlib openssl apr apr-util serf subversion"

	to_build=""

	checkArg expat
	checkArg utf8proc
	checkArg sqlite
	checkArg zlib
	checkArg openssl
	checkArg apr
	checkArg apr-util
	checkArg serf
	checkArg subversion

	if [ -z $to_build ]
	then
		to_build="$BUILD_ALL"
	fi

	buildconfLib expat "git" "--with-docbook"
	cmakeBuildLib utf8proc "git"
	buildLib sqlite $SQLITE_VERSION
	buildLib zlib $ZLIB_VERSION
	buildOpenSLLConfigureLib openssl $OPENSSL_VERSION "zlib --prefix=$my_path/lib_output --openssldir=ssl --with-zlib-lib=$my_path/lib_output/lib/ --with-zlib-include=$my_path/lib_output/include/"
	buildLib apr $APR_VERSION
	buildLib apr-util $APR_UTIL_VERSION "--with-crypto --with-apr=$my_path/lib_output" "--with-apr=$my_path/apr-$APR_VERSION"
	sconsBuildLib serf $SERF_VERSION "APR=$my_path/lib_output APU=$my_path/lib_output OPENSSL=$my_path/lib_output ZLIB=$my_path/lib_output PREFIX=$my_path/lib_output"

	buildLib subversion $SUBVERSION_VERSION "--with-gpg_agent --with-lz4=internal --with-sqlite=$my_path/lib_output --with-serf=$my_path/lib_output --with-apr=$my_path/lib_output --with-apr-util=$my_path/lib_output" "" "-I $my_path/lib_output/include/serf-1/"

	if [[ $args == *"single_library"* ]]
	then
		echo "
		#include <subversion-1/svn_client.h>
		#include <apr-1/apr.h>
		#include <apr-1/apr_time.h>
		void ________import_stub() {
			apr_terminate();
			svn_client_get_simple_provider(0, 0);
			apr_month_snames[0][0];
		}
		" >./m_obj.c
		gcc -fPIC ./m_obj.c -c -o ./m_obj.o -I $my_path/lib_output/include -I $my_path/lib_output/include/apr-1 -nostdlib

		if [ $machine == "Mac" ]
		then
			#there's no way to specify --no-export-dynamic on mac it seems
			gcc -m64 -shared -fPIC -o "$lib_path/libsvn.dylib" \
				./m_obj.o \
				-Wl,-export_dynamic \
				-Wl,-all_load \
				$lib_path/libsvn_client-1.a \
				$lib_path/libsvn_delta-1.a \
				$lib_path/libsvn_fs-1.a \
				$lib_path/libsvn_fs_x-1.a \
				$lib_path/libsvn_fs_fs-1.a \
				$lib_path/libsvn_fs_util-1.a \
				$lib_path/libsvn_subr-1.a \
				$lib_path/libsvn_wc-1.a \
				$lib_path/libsvn_ra-1.a \
				$lib_path/libsvn_ra_local-1.a \
				$lib_path/libsvn_ra_svn-1.a \
				$lib_path/libsvn_ra_serf-1.a \
				$lib_path/libsvn_repos-1.a \
				$lib_path/libsvn_diff-1.a \
				$lib_path/libaprutil-1.a \
				$lib_path/libapr-1.a \
				$lib_path/libserf-1.a \
				$lib_path/libsqlite3.a \
				$lib_path/libssl.a \
				$lib_path/libz.a \
				$lib_path/libutf8proc.a \
				$lib_path/libcrypto.a \
				$lib_path/libexpat.a \
				-Wl,-noall_load \
				-lpthread -lm -ldl -liconv -lsasl2 -framework CoreFoundation -framework Security

			install_name_tool -id "@rpath/libsvn.dylib" "$lib_path/libsvn.dylib"
		else
			gcc -m64 -shared -fPIC -o "$lib_path/libsvn.so" \
				./m_obj.o \
				-Wl,--export-dynamic \
				-Wl,--whole-archive \
				$lib_path/libsvn_client-1.a \
				$lib_path/libsvn_delta-1.a \
				$lib_path/libsvn_fs-1.a \
				$lib_path/libsvn_fs_x-1.a \
				$lib_path/libsvn_fs_fs-1.a \
				$lib_path/libsvn_fs_util-1.a \
				$lib_path/libsvn_subr-1.a \
				$lib_path/libsvn_wc-1.a \
				$lib_path/libsvn_ra-1.a \
				$lib_path/libsvn_ra_local-1.a \
				$lib_path/libsvn_ra_svn-1.a \
				$lib_path/libsvn_ra_serf-1.a \
				$lib_path/libsvn_repos-1.a \
				$lib_path/libsvn_diff-1.a \
				$lib_path/libaprutil-1.a \
				$lib_path/libapr-1.a \
				$lib_path/libserf-1.a \
				$lib_path/libsqlite3.a \
				-Wl,--no-export-dynamic \
				$lib_path/libssl.a \
				$lib_path/libz.a \
				$lib_path/libutf8proc.a \
				$lib_path/libcrypto.a \
				$lib_path/libexpat.a \
				-Wl,--no-whole-archive \
				-lpthread -lm -ldl
		fi
		
				
	fi

	cd ..
}

function gitClone {
	name=$1
	url=$2

	if [[ ! -d $name-git ]]
	then
		git clone $url $name-git
	fi
}

function cmakeBuildLib {
	name=$1

	if [[ $to_build != *"$name"* ]]
	then
		return
	fi

	version=$2
	options=$3

	pwd

	if [ ! -f ./build_$name/CMakeCache.txt ]
	then
		mkdir -p build_$name
		cd build_$name

		my_path=`pwd`

		cmake ../$name-$version -DCMAKE_C_FLAGS="$GLOBAL_CFLAGS" -DCMAKE_INSTALL_PREFIX=$my_path/../lib_output $options
	else
		cd build_$name
	fi
	cmake --build . --target install

	cd ..
	my_path=`pwd`
}

function sconsBuildLib {
	name=$1

	if [[ $to_build != *"$name"* ]]
	then
		return
	fi

	version=$2
	options=$3

	pwd

	if [ -f ./$name-$version/buildconf ]
	then
		cd $name-$version
		./buildconf $options
		cd ..
	fi

	mkdir -p build_$name
	cd build_$name

	my_path=`pwd`

	python $my_path/../../scons-local-2.3.0/scons.py -Y ../$name-$version/ $options CFLAGS="$GLOBAL_CFLAGS" 
	# python $my_path/../../scons-local-2.3.0/scons.py -Y ../$name-$version/ check  CFLAGS="$GLOBAL_CFLAGS" 
	python $my_path/../../scons-local-2.3.0/scons.py -Y ../$name-$version/ install  CFLAGS="$GLOBAL_CFLAGS" 

	cd ..
	my_path=`pwd`
}

function buildLib {
	name=$1

	if [[ $to_build != *"$name"* ]]
	then
		return
	fi

	version=$2
	options=$3
	buildconf_options=$4
	extra_cflags=$5

	if [[ ! -f ./build_$name/Makefile ]]
	then
		mkdir -p ./$name-$version/m4

		mkdir -p build_$name
		cd build_$name

		my_path=`pwd`

		CFLAGS="$GLOBAL_CFLAGS -I $include_path $extra_cflags" ../$name-$version/configure --prefix=$my_path/../lib_output $options
	else
		cd build_$name
	fi

	make
	make install

	cd ..
	my_path=`pwd`
}

function buildOpenSLLConfigureLib {
	name=$1

	if [[ $to_build != *"$name"* ]]
	then
		return
	fi

	version=$2
	options=$3
	buildconf_options=$4
	extra_cflags=$5

	if [[ ! -f ./build_$name/Makefile ]]
	then
		mkdir -p ./$name-$version/m4

		mkdir -p build_$name
		cd build_$name

		my_path=`pwd`

		cp -r ../$name-$version/. ./.
		if [ $machine == "Mac" ]
		then
			options="darwin64-x86_64-cc $options"
		else
			options="linux-x86_64 $options"
		fi
		CFLAGS="$GLOBAL_CFLAGS" ./Configure --prefix=$my_path/../lib_output shared $options
	else
		cd build_$name
	fi

	make
	make install

	cd ..
	my_path=`pwd`
}

function buildconfLib {
	name=$1

	if [[ $to_build != *"$name"* ]]
	then
		return
	fi

	version=$2
	options=$3
	buildconf_options=$4
	extra_cflags=$5

	if [[ ! -f ./build_$name/Makefile ]]
	then
		mkdir -p ./$name-$version/m4
		if [ -f ./$name-$version/buildconf ]
		then
			cd $name-$version
			./buildconf $buildconf_options
			cd ..
		fi

		if [ -f ./$name-$version/buildconf.sh ]
		then
			cd $name-$version
			./buildconf.sh $options
			cd ..
		fi

		mkdir -p build_$name
		cd build_$name

		my_path=`pwd`

		CFLAGS="$GLOBAL_CFLAGS -I $include_path $extra_cflags" ../$name-$version/configure --prefix=$my_path/../lib_output $options
	else
		cd build_$name
	fi

	make
	make install

	cd ..
	my_path=`pwd`
}

function downloadAndExtract {
    name=$1
    version=$2
    override=$3

    if [[ $dl_command == "curl" ]]
    then
    	curl_non_optional="-O"
    fi
    
    pwd
    
    echoColor "    Processing $name"
    
    if [[ ! -f $name-$version.tar.gz && ! -f $name-$version.tar.bz2 ]]
    then
        echoColor "        Downloading $name-$version.tar.gz"
        
        if [ -z $3 ]
        then
            $dl_command $curl_non_optional http://ftp.gnu.org/gnu/$name/$name-$version.tar.gz
        else
            $dl_command $curl_non_optional $override $curl_optional
        fi
    else
        echoColor "        $name-$version.tar.gz already exists"
    fi

    if [ ! -d $name-$version ]
    then
        echoColor "        Extracting $name-$version.tar.gz"

        if [[ -f $name-$version.tar.gz ]]
        then
        	tar -xf $name-$version.tar.gz
        else
        	tar -xf $name-$version.tar.bz2
        fi
    else
        echoColor "        Folder $name-$version already exists"
    fi
}

function echoColor {
    echo -e "\x1B[96m$1\x1B[39m"
}

main
