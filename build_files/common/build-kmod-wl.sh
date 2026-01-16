#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ -n "$(rpm -E '%fedora' | grep -v %fedora)" ]]; then
    RELEASE="$(rpm -E '%fedora')"
    SUFFIX="fc${RELEASE}"
elif [[ -n "$(rpm -E '%rhel' | grep -v %rhel)" ]]; then
    RELEASE="$(rpm -E '%rhel')"
    SUFFIX="el${RELEASE}"
else
    echo "Unknown distro release, skipping wl"
    exit 0
fi


### BUILD wl (succeed or fail-fast with debug output)
if ! dnf install -y \
    akmod-wl-*.${SUFFIX}."${ARCH}"; then
    echo "Failed to install akmod-wl, skipping..."
    exit 0
fi
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/"${KERNEL}"/extra/wl/wl.ko.xz > /dev/null \
|| (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)
