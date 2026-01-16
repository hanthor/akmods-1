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
    echo "Unknown distro release, skipping xone"
    exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

SPEC_FILE="/root/rpmbuild/SPECS/xone-kmod.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "Spec file $SPEC_FILE not found, skipping xone build"
    exit 0
fi

# Build the -common package first (required dependency for akmod)
COMMON_SPEC="/root/rpmbuild/SPECS/xone-kmod-common.spec"
if [ -f "$COMMON_SPEC" ]; then
    echo "Building xone-kmod-common package..."
    rpmbuild -bb "$COMMON_SPEC" || echo "Warning: xone-kmod-common build failed, continuing..."
    COMMON_RPM=$(find /root/rpmbuild/RPMS -name "xone-kmod-common-*.rpm" -type f | head -n1)
    if [ -n "$COMMON_RPM" ]; then
        dnf install -y "$COMMON_RPM"
    fi
fi

rpmbuild -bb "$SPEC_FILE"

# Install generated akmod package - find them dynamically
AKMOD_RPM=$(find /root/rpmbuild/RPMS -name "akmod-xone-*.rpm" -type f | head -n1)
if [ -n "$AKMOD_RPM" ]; then
    dnf install -y "$AKMOD_RPM"
else
    echo "Warning: akmod-xone RPM not found"
fi

akmods --force --kernels "${KERNEL}" --kmod xone
modinfo /usr/lib/modules/"${KERNEL}"/extra/xone/xone_{dongle,gip,gip_gamepad,gip_headset,gip_chatpad,gip_madcatz_strat,gip_madcatz_glam,gip_pdp_jaguar}.ko.xz > /dev/null \
|| (find /var/cache/akmods/xone/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
