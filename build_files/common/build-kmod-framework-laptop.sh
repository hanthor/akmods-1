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
# Check if this kernel provides the necessary ChromeOS EC symbols
# (Missing in official RHEL/AlmaLinux kernels, requires custom/Plus kernel)
KERNEL_DEVEL_DIR="/usr/src/kernels/${KERNEL}"
if [ -f "${KERNEL_DEVEL_DIR}/Module.symvers" ]; then
    if ! grep -q "cros_ec_cmd" "${KERNEL_DEVEL_DIR}/Module.symvers"; then
        echo "Skipping framework-laptop: kernel headers do not provide cros_ec_cmd"
        echo "This driver requires a kernel with CONFIG_CROS_EC enabled."
        exit 0
    fi
else
    echo "Warning: ${KERNEL_DEVEL_DIR}/Module.symvers not found, attempting build anyway..."
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
    if ! rpmbuild -bb "$COMMON_SPEC"; then
        echo "WARNING: framework-laptop-kmod-common rpmbuild failed. Skipping framework-laptop."
        rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
        exit 0
    fi
fi

# Build akmod package from spec
if ! rpmbuild -bb "$SPEC_FILE"; then
    echo "WARNING: framework-laptop-kmod rpmbuild failed. Skipping framework-laptop."
    rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
    exit 0
fi

# Install both common and akmod packages together to satisfy dependencies
COMMON_RPM=$(find /root/rpmbuild/RPMS -name "framework-laptop-kmod-common-*.rpm" -type f | head -n1)
AKMOD_RPM=$(find /root/rpmbuild/RPMS -name "akmod-framework-laptop-*.rpm" -type f | head -n1)

if [ -z "$AKMOD_RPM" ]; then
    echo "WARNING: akmod-framework-laptop RPM not found. Skipping framework-laptop."
    find /root/rpmbuild/RPMS -type f -name "*.rpm" || true
    rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
    exit 0
fi

if ! dnf install -y $COMMON_RPM "$AKMOD_RPM"; then
    echo "WARNING: framework-laptop RPM install failed. Skipping."
    rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
    exit 0
fi

if ! akmods --force --kernels "${KERNEL}" --kmod framework-laptop; then
    echo "WARNING: framework-laptop kernel module build failed."
    echo "Skipping framework-laptop — upstream driver may not yet support this kernel version."
    find /var/cache/akmods/framework-laptop/ -name \*.log -print -exec cat {} \; 2>/dev/null || true
    rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
    exit 0
fi
modinfo /usr/lib/modules/"${KERNEL}"/extra/framework-laptop/framework_laptop.ko.xz > /dev/null \
|| (find /var/cache/akmods/framework-laptop/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
