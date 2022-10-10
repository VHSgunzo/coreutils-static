#!/bin/bash

export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1
# NO_SYS_MUSL=1

# coreutils_version="8.28"
# musl_version="1.1.15"

coreutils_version="latest"
musl_version="latest"

platform="$(uname -s)"
platform_arch="$(uname -m)"

[ "$coreutils_version" == "latest" ] && \
  coreutils_version="$(curl -s https://ftp.gnu.org/gnu/coreutils/|tac|\
                       grep -om1 'coreutils-.*\.tar\.xz'|cut -d'>' -f2|sed 's|coreutils-||g;s|.tar.xz||g')"

[ "$musl_version" == "latest" ] && \
  musl_version="$(curl -s https://www.musl-libc.org/releases/|tac|grep -v 'latest'|\
                  grep -om1 'musl-.*\.tar\.gz'|cut -d'>' -f2|sed 's|musl-||g;s|.tar.gz||g')"

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
pushd build

# download tarballs
echo "= downloading coreutils v${coreutils_version}"
curl -LO https://ftp.gnu.org/gnu/coreutils/coreutils-${coreutils_version}.tar.xz

echo "= extracting coreutils"
tar -xJf coreutils-${coreutils_version}.tar.xz

if [ "$platform" == "Linux" ]
    then
        echo "= setting CC to musl-gcc"
        if [[ ! -x "$(which musl-gcc 2>/dev/null)" || "$NO_SYS_MUSL" == 1 ]]
            then
                echo "= downloading musl v${musl_version}"
                curl -LO https://www.musl-libc.org/releases/musl-${musl_version}.tar.gz

                echo "= extracting musl"
                tar -xf musl-${musl_version}.tar.gz

                echo "= building musl"
                working_dir="$(pwd)"

                install_dir="${working_dir}/musl-install"

                pushd musl-${musl_version}
                env CFLAGS="$CFLAGS -Os -ffunction-sections -fdata-sections" LDFLAGS='-Wl,--gc-sections' ./configure --prefix="${install_dir}"
                make install
                popd # musl-${musl-version}
                export CC="${working_dir}/musl-install/bin/musl-gcc"
            else
                export CC="$(which musl-gcc 2>/dev/null)"
        fi
        export CFLAGS="-static"
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building coreutils"
pushd coreutils-${coreutils_version}
env FORCE_UNSAFE_CONFIGURE=1 CFLAGS="$CFLAGS -Os -ffunction-sections -fdata-sections" LDFLAGS='-Wl,--gc-sections' ./configure
make
popd # coreutils-${coreutils_version}

popd # build

shopt -s extglob

echo "= extracting coreutils binary"
cp build/coreutils-${coreutils_version}/src/!(*.*) release 2>/dev/null

echo "= striptease"
for file in release/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
tar --xz -acf coreutils-static-v${coreutils_version}-${platform_arch}.tar.xz release

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= coreutils v${coreutils_version} done"
