#!/usr/bin/bash
set "${CI:+-x}" -euo pipefail

echo "DEBUG: ENV KERNEL_NAME='${KERNEL_NAME}'"
echo "DEBUG: Installed Kernels (rpm -qa):"
rpm -qa | grep kernel || echo "DEBUG: rpm -q found nothing"
echo "DEBUG: Installed Kernels (dnf list installed):"
dnf list installed kernel* || echo "DEBUG: dnf list failed"
echo "DEBUG: /lib/modules content:"
ls -F /lib/modules/ || echo "DEBUG: /lib/modules empty or missing"

if ! rpm -q "${KERNEL_NAME}" &>/dev/null; then
    echo "DEBUG: ${KERNEL_NAME} metapackage missing."
    if rpm -q kernel-core &>/dev/null; then
        echo "DEBUG: kernel-core found, switching KERNEL_NAME."
        KERNEL_NAME="kernel-core"
    else
        echo "DEBUG: kernel-core ALSO missing from rpm -q check."
    fi
fi
echo "DEBUG: Final KERNEL_NAME='${KERNEL_NAME}'"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
echo "DEBUG: Resolved KERNEL='${KERNEL}'"
if [[ -n "$(rpm -E '%fedora' | grep -v %fedora)" ]]; then
    RELEASE="$(rpm -E '%fedora')"
    SUFFIX="fc${RELEASE}"
elif [[ -n "$(rpm -E '%rhel' | grep -v %rhel)" ]]; then
    RELEASE="$(rpm -E '%rhel')"
    SUFFIX="el${RELEASE}"
else
    echo "Unknown distro release, skipping framework-laptop"
    exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

SPEC_FILE="/root/rpmbuild/SPECS/framework-laptop-kmod.spec"
if [ ! -f "$SPEC_FILE" ]; then
    echo "Spec file $SPEC_FILE not found, skipping framework-laptop build"
    exit 0
fi

# Build the -common package first (required dependency for akmod)
COMMON_SPEC="/root/rpmbuild/SPECS/framework-laptop-kmod-common.spec"
if [ -f "$COMMON_SPEC" ]; then
    echo "Building framework-laptop-kmod-common package..."
    rpmbuild -bb "$COMMON_SPEC"
    COMMON_RPM=$(find /root/rpmbuild/RPMS -name "framework-laptop-kmod-common-*.rpm" -type f | head -n1)
    if [ -n "$COMMON_RPM" ]; then
        dnf install -y "$COMMON_RPM"
    fi
fi

# Build akmod package from spec
rpmbuild -bb "$SPEC_FILE"

# Install generated akmod package(s) - may be in noarch or arch-specific dir
AKMOD_RPM=$(find /root/rpmbuild/RPMS -name "akmod-framework-laptop-*.rpm" -type f | head -n1)
if [ -z "$AKMOD_RPM" ]; then
    echo "ERROR: akmod-framework-laptop RPM not found in /root/rpmbuild/RPMS/"
    find /root/rpmbuild/RPMS -type f -name "*.rpm" || true
    exit 1
fi
dnf install -y "$AKMOD_RPM"

akmods --force --kernels "${KERNEL}" --kmod framework-laptop
modinfo /usr/lib/modules/"${KERNEL}"/extra/framework-laptop/framework_laptop.ko.xz > /dev/null \
|| (find /var/cache/akmods/framework-laptop/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
