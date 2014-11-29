#!/bin/bash

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

TOP="$(dirname "$0")"

PROJECT=libxml2
LICENSE=Copyright
VERSION="2.9.2"
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

stage="$(pwd)"
[ -f "$stage"/packages/include/zlib/zlib.h ] || fail "You haven't installed packages yet."

pushd "$TOP/$SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            pushd "$TOP/$SOURCE_DIR/win32"

                cscript configure.js zlib=yes icu=yes static=yes debug=yes python=no iconv=no \
                    compiler=msvc \
                    include="$(cygpath -w $stage/packages/include);$(cygpath -w $stage/packages/include/zlib)" \
                    lib="$(cygpath -w $stage/packages/lib);$(cygpath -w $stage/packages/lib/debug)" \
                    prefix="$(cygpath -w $stage)" \
                    sodir="$(cygpath -w $stage/lib/debug)" \
                    libdir="$(cygpath -w $stage/lib/debug)"

                nmake /f Makefile.msvc ZLIB_LIBRARY=zlibd.lib all
                nmake /f Makefile.msvc install
                cp -f $stage/packages/lib/debug/icu*.dll "bin.msvc"
                cp -f $stage/packages/lib/release/icudt*.dll "bin.msvc"

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    nmake /f Makefile.msvc checktests
                fi

                nmake /f Makefile.msvc clean

                cscript configure.js zlib=yes icu=yes static=yes debug=no python=no iconv=no \
                    compiler=msvc \
                    include="$(cygpath -w $stage/packages/include);$(cygpath -w $stage/packages/include/zlib)" \
                    lib="$(cygpath -w $stage/packages/lib);$(cygpath -w $stage/packages/lib/release)" \
                    prefix="$(cygpath -w $stage)" \
                    sodir="$(cygpath -w $stage/lib/release)" \
                    libdir="$(cygpath -w $stage/lib/release)"

                nmake /f Makefile.msvc ZLIB_LIBRARY=zlib.lib all
                nmake /f Makefile.msvc install
                cp -f $stage/packages/lib/release/icu*.dll "bin.msvc"

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    nmake /f Makefile.msvc checktests
                fi

                nmake /f Makefile.msvc clean
            popd
        ;;

        "windows64")
            load_vsvars

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            pushd "$TOP/$SOURCE_DIR/win32"

                cscript configure.js zlib=yes icu=yes static=yes debug=yes python=no iconv=no \
                    compiler=msvc \
                    include="$(cygpath -w $stage/packages/include);$(cygpath -w $stage/packages/include/zlib)" \
                    lib="$(cygpath -w $stage/packages/lib64);$(cygpath -w $stage/packages/lib/debug)" \
                    prefix="$(cygpath -w $stage)" \
                    sodir="$(cygpath -w $stage/lib/debug)" \
                    libdir="$(cygpath -w $stage/lib/debug)"

                nmake /f Makefile.msvc ZLIB_LIBRARY=zlibd.lib all
                nmake /f Makefile.msvc install
                cp -f $stage/packages/lib/debug/icu*.dll "bin.msvc"
                cp -f $stage/packages/lib/release/icudt*.dll "bin.msvc"

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    nmake /f Makefile.msvc checktests
                fi

                nmake /f Makefile.msvc clean

                cscript configure.js zlib=yes icu=yes static=yes debug=no python=no iconv=no \
                    compiler=msvc \
                    include="$(cygpath -w $stage/packages/include);$(cygpath -w $stage/packages/include/zlib)" \
                    lib="$(cygpath -w $stage/packages/lib64);$(cygpath -w $stage/packages/lib/release)" \
                    prefix="$(cygpath -w $stage)" \
                    sodir="$(cygpath -w $stage/lib/release)" \
                    libdir="$(cygpath -w $stage/lib/release)"

                nmake /f Makefile.msvc ZLIB_LIBRARY=zlib.lib all
                nmake /f Makefile.msvc install
                cp -f $stage/packages/lib/release/icu*.dll "bin.msvc"

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    nmake /f Makefile.msvc checktests
                fi

                nmake /f Makefile.msvc clean
            popd
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
            if [ -x /usr/bin/gcc-4.6 -a -x /usr/bin/g++-4.6 ]; then
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
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first

            # CPPFLAGS will be used by configure and we need to
            # get the dependent packages in there as well.  Process
            # may find the system zlib.h but it won't find the
            # packaged one.
            PATH="$stage/packages/bin:$PATH" \
                CFLAGS="$opts -g -O0 -I$stage/packages/include/zlib" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="$opts -g -L$stage/packages/lib/debug" \
                ./configure --with-python=no --with-pic --with-zlib \
                --disable-shared --enable-static \
                --prefix="$stage" --libdir="$stage"/lib/debug
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean

            # Release last
            PATH="$stage/packages/bin:$PATH" \
                CFLAGS="$opts -g -O2 -I$stage/packages/include/zlib" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib" \
                LDFLAGS="$opts -g -L$stage/packages/lib/release" \
                ./configure --with-python=no --with-pic --with-zlib \
                --disable-shared --enable-static \
                --prefix="$stage" --libdir="$stage"/lib/release
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean
        ;;
        "linux64")
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

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m64}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first

            # CPPFLAGS will be used by configure and we need to
            # get the dependent packages in there as well.  Process
            # may find the system zlib.h but it won't find the
            # packaged one.
            PATH=$stage/packages/bin:$PATH \
                CFLAGS="$opts -g -Og -I$stage/packages/include -I$stage/packages/include/zlib" \
                CXXFLAGS="$opts -g -Og -std=c++11 -I$stage/packages/include -I$stage/packages/include/zlib" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include -I$stage/packages/include/zlib" \
                LDFLAGS="$opts -g -std=c++11 -L$stage/packages/lib/debug" \
                LIBS="-lstdc++" \
                ./configure --with-python=no \
                --with-zlib --with-icu \
                --without-http --without-ftp --without-iconv --without-lzma \
                --disable-shared --enable-static --with-pic \
                --prefix="$stage" --libdir="$stage"/lib/debug
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean

            # Release last
            PATH=$stage/packages/bin:$PATH \
                CFLAGS="$opts -O2 -I$stage/packages/include -I$stage/packages/include/zlib" \
                CXXFLAGS="$opts -O2 -std=c++11 -I$stage/packages/include -I$stage/packages/include/zlib" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include -I$stage/packages/include/zlib" \
                LDFLAGS="$opts -std=c++11 -L$stage/packages/lib/release" \
                LIBS="-lstdc++" \
                ./configure --with-python=no \
                --with-zlib --with-icu \
                --without-http --without-ftp --without-iconv --without-lzma \
                --disable-shared --enable-static --with-pic \
                --prefix="$stage" --libdir="$stage"/lib/release
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean
        ;;
        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk/
            
            opts="${TARGET_OPTS:--arch i386 -arch x86_64 -iwithsysroot $sdk -mmacosx-version-min=10.7}"

            # Debug first

            # CPPFLAGS will be used by configure and we need to
            # get the dependent packages in there as well.  Process
            # may find the system zlib.h but it won't find the
            # packaged one.
            CFLAGS="$opts -O0 -gdwarf-2 -I$stage/packages/include/zlib" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib -stdlib=libc++" \
                LDFLAGS="$opts -gdwarf-2 -L$stage/packages/lib/debug -stdlib=libc++" \
                CC="clang" CXX="clang++" \
                ./configure --with-python=no --with-pic \
                --with-zlib="${stage}/packages/lib/debug" \
                --with-icu="${stage}/packages/lib/debug" \
                --without-http --without-ftp --without-iconv \
                --disable-shared --enable-static \
                --prefix="$stage" --libdir="$stage/lib/debug"
            make 
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean

            # Release last for configuration headers
            CFLAGS="$opts -O2 -gdwarf-2 -I$stage/packages/include/zlib -I$stage/packages/include/unicode" \
                CPPFLAGS="$CPPFLAGS -I$stage/packages/include/zlib -I$stage/packages/include/unicode -stdlib=libc++" \
                LDFLAGS="$opts -gdwarf-2 -L$stage/packages/lib/release -stdlib=libc++" \
                ./configure --with-python=no --with-pic \
                --with-zlib="${stage}/packages/lib/release" \
                --with-icu="${stage}/packages/lib/release" \
                --without-http --without-ftp --without-iconv \
                --disable-shared --enable-static \
                --prefix="$stage" --libdir="$stage/lib/release"
            make 
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make clean
        ;;

        *)
            echo "platform not supported"
            fail
        ;;
    esac
popd

mkdir -p "$stage/LICENSES"
cp "$TOP/$SOURCE_DIR/$LICENSE" "$stage/LICENSES/$PROJECT.txt"
mkdir -p "$stage"/docs/libxml2/
cp -a "$TOP"/README.Linden "$stage"/docs/libxml2/

pass

