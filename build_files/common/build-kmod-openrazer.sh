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
    rpmbuild -bb "$COMMON_SPEC"
fi

# Build akmod package
rpmbuild -bb "$SPEC_FILE"

# Install both common and akmod packages together to satisfy dependencies
COMMON_RPM=$(find /root/rpmbuild/RPMS -name "openrazer-kmod-common-*.rpm" -type f | head -n1)
AKMOD_RPM=$(find /root/rpmbuild/RPMS -name "akmod-openrazer-*.rpm" -type f | head -n1)

if [ -z "$AKMOD_RPM" ]; then
    echo "ERROR: akmod-openrazer RPM not found"
    exit 1
fi

dnf install -y $COMMON_RPM "$AKMOD_RPM"

if ! akmods --force --kernels "${KERNEL}" --kmod openrazer; then
    echo "WARNING: openrazer kernel module build failed (likely kernel API incompatibility)."
    echo "Skipping openrazer — upstream driver may not yet support this kernel version."
    find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; 2>/dev/null || true
    rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
    exit 0
fi
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkbd.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razermouse.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkraken.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razeraccessory.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
