#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail


ARCH="$(rpm -E '%_arch')"
if ! rpm -q "${KERNEL_NAME}" &>/dev/null; then
    if rpm -q kernel-core &>/dev/null; then
        KERNEL_NAME="kernel-core"
    fi
fi
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ -n "$(rpm -E '%fedora' | grep -v %fedora)" ]]; then
    RELEASE="$(rpm -E '%fedora')"
    SUFFIX="fc${RELEASE}"
elif [[ -n "$(rpm -E '%rhel' | grep -v %rhel)" ]]; then
    RELEASE="$(rpm -E '%rhel')"
    SUFFIX="el${RELEASE}"
else
    echo "Unknown distro release, skipping v4l2loopback"
    exit 0
fi

SPEC_FILE="/root/rpmbuild/SPECS/v4l2loopback.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "Spec file $SPEC_FILE not found, skipping v4l2loopback build"
    exit 0
fi

rpmbuild -bb "$SPEC_FILE"

# Install generated akmod package
dnf install -y /root/rpmbuild/RPMS/*/*v4l2loopback*.rpm

akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/"${KERNEL}"/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
