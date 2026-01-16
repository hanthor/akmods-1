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
    echo "Unknown distro release, skipping openrazer"
    exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

SPEC_FILE="/root/rpmbuild/SPECS/openrazer-kmod.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "Spec file $SPEC_FILE not found, skipping openrazer build"
    exit 0
fi

# Build the -common package first (required dependency for akmod)
COMMON_SPEC="/root/rpmbuild/SPECS/openrazer-kmod-common.spec"
if [ -f "$COMMON_SPEC" ]; then
    echo "Building openrazer-kmod-common package..."
    rpmbuild -bb "$COMMON_SPEC" || echo "Warning: openrazer-kmod-common build failed, continuing..."
    COMMON_RPM=$(find /root/rpmbuild/RPMS -name "openrazer-kmod-common-*.rpm" -type f | head -n1)
    if [ -n "$COMMON_RPM" ]; then
        dnf install -y "$COMMON_RPM"
    fi
fi

# Build akmod and common packages
rpmbuild -bb "$SPEC_FILE"

# Install generated packages - find dynamically
AKMOD_RPM=$(find /root/rpmbuild/RPMS -name "akmod-openrazer-*.rpm" -type f | head -n1)
if [ -n "$AKMOD_RPM" ]; then
    dnf install -y "$AKMOD_RPM"
else
    echo "Warning: akmod-openrazer RPM not found"
fi

akmods --force --kernels "${KERNEL}" --kmod openrazer
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkbd.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razermouse.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkraken.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razeraccessory.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
