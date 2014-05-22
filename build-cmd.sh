#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PROJECT="gmock"
SOURCE_DIR="$PROJECT"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            pushd msvc/2010
                load_vsvars
                build_sln "$PROJECT.sln" "Debug|Win32"
                build_sln "$PROJECT.sln" "Release|Win32"

                mkdir -p "$stage/lib/debug"
                mkdir -p "$stage/lib/release"

                cp -a Release/*\.lib $stage/lib/release/
                cp -a Debug/*\.lib $stage/lib/debug/

                # copy headers
                mkdir -p "$stage/include/$PROJECT"
                mkdir -p "$stage/include/gtest"
            popd
            cp -a include "$stage/"
            cp -a gtest/include "$stage/"
        ;;

        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/

            opts="${TARGET_OPTS:--arch i386 -iwithsysroot $sdk -mmacosx-version-min=10.6}"

            # Debug first
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" \
                CFLAGS="$opts -O0 -gdwarf-2" \
                CXXFLAGS="$opts -O0 -gdwarf-2" \
                LDFLAGS="-L$stage/packages/lib/debug" \
                ./configure --with-pic --enable-static=yes --enable-shared=no \
                --prefix="$stage" --libdir="$stage"/lib/debug
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make distclean

            # Release last
            CPPFLAGS="-DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" \
                CFLAGS="$opts -gdwarf-2" \
                CXXFLAGS="$opts -gdwarf-2" \
                LDFLAGS="-L$stage/packages/lib/release" \
                ./configure --with-pic --enable-static=yes --enable-shared=no \
                --prefix="$stage" --libdir="$stage"/lib/release
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
            make distclean
        ;;

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.6 if available.
            if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export cppflags="$TARGET_CPPFLAGS"
            fi

            # Debug first
            CPPFLAGS="${cppflags} -DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" \
                CFLAGS="$opts -O0 -g" \
                CXXFLAGS="$opts -O0 -g" \
                LDFLAGS="-L$stage/packages/lib/debug" \
                ./configure --with-pic --enable-static=yes --enable-shared=no \
                --prefix="$stage" --libdir="$stage"/lib/debug
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
            make distclean

            # Release last
            CPPFLAGS="${cppflags} -DUSE_BOOST_TYPE_TRAITS -I$stage/packages/include" \
                CFLAGS="$opts" \
                CXXFLAGS="$opts" \
                LDFLAGS="-L$stage/packages/lib/release" \
                ./configure --with-pic --enable-static=yes --enable-shared=no \
                --prefix="$stage" --libdir="$stage"/lib/release
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi
            
            make distclean
        ;;
    esac

    # copy license info
    mkdir -p "$stage/LICENSES"
    cp -a COPYING  "$stage/LICENSES/$PROJECT.txt"
popd

mkdir -p "$stage"/docs/google-mock/
cp -a README.Linden "$stage"/docs/google-mock/

pass

