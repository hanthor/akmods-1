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
    echo "Unknown distro release, skipping wl"
    exit 0
fi


SPEC_FILE="/root/rpmbuild/SPECS/broadcom-wl.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "Spec file $SPEC_FILE not found, skipping wl build"
    exit 0
fi

if ! rpmbuild -bb "$SPEC_FILE"; then
    echo "WARNING: broadcom-wl rpmbuild failed (missing build dependencies?)."
    echo "Skipping wl."
    exit 0
fi

# Install generated akmod package
if ! dnf install -y /root/rpmbuild/RPMS/*/*wl*.rpm; then
    echo "WARNING: broadcom-wl RPM install failed. Skipping."
    exit 0
fi

if ! akmods --force --kernels "${KERNEL}" --kmod wl; then
    echo "WARNING: wl kernel module build failed (likely kernel API incompatibility)."
    echo "Skipping wl — upstream driver may not yet support this kernel version."
    find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; 2>/dev/null || true
    exit 0
fi
if ! modinfo /usr/lib/modules/"${KERNEL}"/extra/wl/wl.ko.xz > /dev/null 2>&1; then
    echo "WARNING: wl module not found after akmods build."
    find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; 2>/dev/null || true
    exit 0
fi
