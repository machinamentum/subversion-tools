#!/bin/bash

SUBVERSION_VERSION=1.10.2
APR_VERSION=1.6.3
APR_UTIL_VERSION=1.6.1
ZLIB_VERSION=1.2.11
SERF_VERSION=1.3.9
OPENSSL_VERSION=1.0.2p
SCONS_VERSION=2.3.0
SQLITE_VERSION=autoconf-3240000

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
	git clone https://github.com/JuliaStrings/utf8proc.git utf8proc-git

	mkdir -p lib_output
	my_path=`pwd`

	cmakeBuildLib utf8proc "git"
	buildLib sqlite $SQLITE_VERSION
	buildLib zlib $ZLIB_VERSION
	buildLib apr $APR_VERSION
	buildLib apr-util $APR_UTIL_VERSION "--with-apr=$my_path/lib_output"
	buildLib openssl $OPENSSL_VERSION "darwin64-x86_64-cc zlib"
	sconsBuildLib serf $SERF_VERSION "APR=$my_path/lib_output APU=$my_path/lib_output OPENSSL=$my_path/lib_output PREFIX=$my_path/lib_output"

	buildLib subversion $SUBVERSION_VERSION "--with-lz4=internal --with-sqlite=$my_path/lib_output --with-serf=$my_path/lib_output --with-apr=$my_path/lib_output --with-apr-util=$my_path/lib_output"

	cd ..
}

function cmakeBuildLib {
	name=$1
	version=$2
	options=$3

	pwd

	if [ -f ./$name-$version/buildconf ]
	then
		cd $name-$version
		./buildconf
		cd ..
	fi

	mkdir -p build_$name
	cd build_$name

	my_path=`pwd`

	cmake ../$name-$version -DCMAKE_INSTALL_PREFIX=$my_path/../lib_output $options
	cmake --build . --target install

	cd ..
	my_path=`pwd`
}

function sconsBuildLib {
	name=$1
	version=$2
	options=$3

	pwd

	if [ -f ./$name-$version/buildconf ]
	then
		cd $name-$version
		./buildconf
		cd ..
	fi

	mkdir -p build_$name
	cd build_$name

	my_path=`pwd`

	python $my_path/../../scons-local-2.3.0/scons.py -Y ../$name-$version/ $options
	python $my_path/../../scons-local-2.3.0/scons.py -Y ../$name-$version/ install

	cd ..
	my_path=`pwd`
}

function buildLib {
	name=$1
	version=$2
	options=$3

	if [ -f ./$name-$version/buildconf ]
	then
		cd $name-$version
		./buildconf
		cd ..
	fi

	mkdir -p build_$name
	cd build_$name

	my_path=`pwd`

	if [ -f ../$name-$version/Configure ]
	then
		cp -r ../$name-$version/. ./.
		if [ $machine == "Mac" ]
		then
			options = darwin64-x86_64-cc $options
		fi
		./Configure --prefix=$my_path/../lib_output $options
	else
		../$name-$version/configure --prefix=$my_path/../lib_output $options
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
    
    if [ ! -f $name-$version.tar.gz ]
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
        tar -xf $name-$version.tar.gz

        if [ $? ]
        then
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