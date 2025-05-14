#!/bin/bash
set -ex
# check dependencies
if [ "$UID" -eq 0 ] && command -v apt ; then
    apt-get update
    apt-get install -yq build-essential linux-source bc \
        kmod cpio flex libncurses5-dev libelf-dev libssl-dev \
        dwarves bison debhelper-compat wget xz-utils
fi
ver="$1"
if [ "$ver" == "" ] ; then
    ver=$(wget -O - https://kernel.org/ | grep "downloadarrow_small.png" \
      | sed "s/.*href=\"//g;s/\".*//g;s/.*linux-//g;s/\.tar.*//g")
fi
mkdir -p work
cd work
# Fetch kernel
if [ ! -d linux-${ver} ] ; then
    wget -O - https://cdn.kernel.org/pub/linux/kernel/v${ver/.*/}.x/linux-${ver}.tar.xz | tar -xvJf -
fi
# copy config
if [ -f /proc/config.gz ] ; then
    gzip -d /proc/config.gz -c > linux-${ver}/.config
elif [ -f /boot/config-$(uname -r) ] ; then
    cat /boot/config-$(uname -r) > linux-${ver}/.config
else
    wget -O linux-${ver}/.config https://gitlab.archlinux.org/archlinux/packaging/packages/linux-lts/-/raw/main/config
fi
yes "" | make oldconfig -C linux-${ver}
# configure
cd linux-${ver}
# disable hibernate
./scripts/config --disable CONFIG_HIBERNATION
./scripts/config --disable CONFIG_HIBERNATION_SNAPSHOT_DEV
./scripts/config --disable CONFIG_HIBERNATE_CALLBACKS
# disable signinig
./scripts/config --disable CONFIG_MODULE_SIG_ALL
# embed all filesystem modules
grep "^CONFIG_[A-Z0-9]*_FS=m" .config  | cut -f1 -d"=" | while read cfg ; do
    ./scripts/config --enable $cfg
done
# compress type
# enable gzip and uncompress modules
grep "^CONFIG_KERNEL_[A-Z]*" .config  | cut -f1 -d"=" | while read cfg ; do
    ./scripts/config --disable $cfg
done
./scripts/config --enable CONFIG_KERNEL_GZIP
# schedutil governor
./scripts/config --enable CONFIG_CPU_FREQ_GOV_SCHEDUTIL
./scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
# build the deb package
cd ..
yes "" | make bindeb-pkg -C linux-${ver} -j`nproc`
