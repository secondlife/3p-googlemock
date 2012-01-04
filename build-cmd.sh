#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PROJECT="gmock"
VERSION="1.5.0"
SOURCE_DIR="$PROJECT"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            pushd msvc
            load_vsvars
            build_sln "$PROJECT.sln" "Debug|Win32"
            build_sln "$PROJECT.sln" "Release|Win32"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            cp Release/*\.lib $stage/lib/release/
            cp Debug/*\.lib $stage/lib/debug/

            # copy headers
            mkdir -p "$stage/include/$PROJECT"
            popd
            cp -rv include "$stage/"

        ;;
        "darwin")
            # TODO: fix the mac build
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" ./configure --prefix="$stage"
            make
            make install
            
            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
        "linux")
            # Prefer gcc-4.1 if available. 
            if [[ -f /usr/bin/gcc-4.1 && -f /usr/bin/g++-4.1 ]] ; then
                export CC=gcc-4.1
                export CXX=g++-4.1
            fi
            
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" CFLAGS="-m32 -O2" CXXFLAGS="-m32" ./configure --prefix="$stage" --libdir="$stage/lib/release"
            make
            make install
            
            make distclean
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" CFLAGS="-m32 -O0 -g" CXXFLAGS="-m32" ./configure --prefix="$stage" --libdir="$stage/lib/debug"
            make
            make install
            
        ;;
    esac

	# copy license info
    mkdir -p "$stage/LICENSES"
    cp COPYING  "$stage/LICENSES/$PROJECT.txt"
popd

pass

