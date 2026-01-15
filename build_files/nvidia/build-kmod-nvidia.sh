#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KMOD_REPO="${1:-nvidia}"

DIST="$(rpm -E '%dist')"
DIST="${DIST#.}"
VARS_KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    # enable negativo17
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-epel-${KMOD_REPO}.repo" /etc/yum.repos.d/
elif [[ "${KERNEL_FLAVOR}" =~ "almalinux" ]]; then
    dnf install -y almalinux-release-nvidia-driver
    dnf config-manager --set-enabled almalinux-nvidia
else
    # disable rpmfusion and enable negativo17
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/rpmfusion-*.repo
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-fedora-${KMOD_REPO}.repo" /etc/yum.repos.d/
fi
export KERNEL_MODULE_TYPE=open
if [[ "${KMOD_REPO}" =~ "lts" ]]; then
    export KERNEL_MODULE_TYPE=kernel
fi
DEPRECATED_RELEASE="${DIST}.${ARCH}"

cd /tmp

### BUILD nvidia

if [[ "${KERNEL_FLAVOR}" =~ "almalinux" ]]; then
    # AlmaLinux provided drivers
    
    # We want to grab specific packages, but they might change version often.
    # We'll try to grab the latest available for our kernel if possible, or just latest.
    # dnf download to current dir (/tmp)
    # The containerfile expects rpms in /var/cache/rpms/kmods/nvidia? No, look at bottom.
    
    dnf download -y \
        nvidia-open-kmod \
        nvidia-driver \
        nvidia-settings \
        nvidia-modprobe \
        nvidia-persistenced \
        nvidia-libXNVCtrl \
        kmod-nvidia-open
    
    # We can't query rpm-qa for version info like below easily if we haven't installed them.
    # Let's inspect ONE of the downloaded rpms to get version.
    # Assuming kmod-nvidia-open is what we use for versioning akmod equivalent.
    
    # But wait, akmods logic puts things in /var/cache/rpms/kmods/nvidia at the end?
    # No, line 51 mkdir.
    # Existing logic installs akmod-nvidia, builds it, and then... where does it put output?
    # akmods command installs into /var/cache/akmods/nvidia... 
    # The goal of this script seems to be populating /var/cache/rpms/kmods/nvidia?
    # Actually, let's look at Containerfile.in again.
    # It copies /tmp/build-kmod-nvidia.sh but doesn't seem to copy artifacts out explicitly?
    # Ah, Containerfile.in: 
    # cp /tmp/ublue-os-nvidia-addons/rpmbuild/RPMS/noarch/ublue-os-nvidia-addons*.rpm /var/cache/rpms/ublue-os/
    # And then runs build-kmod-nvidia.sh.
    # Then in COPY --from=builder /var/cache/rpms /rpms
    
    # So we need to put our RPMs into /var/cache/rpms/kmods/nvidia?
    # No, akmods produces rpms in typical locations.
    # The script normally does: `akmods --force` which installs the produced kmod RPM.
    # But wait, `akmods` usually installs the built RPMs? No.
    # `akmods` builds and putting results in /var/cache/akmods/...
    
    # This script is confusing.
    # "modinfo ..." check.
    # "mkdir -p /var/cache/rpms/kmods/nvidia"
    
    # I think for almalinux we just want to download the RPMs into the cache dir so they end up in the final image.
    mkdir -p /var/cache/rpms/kmods/nvidia
    mv *.rpm /var/cache/rpms/kmods/nvidia/
    
    # Determine versions for the vars file
    # We can inspect one of the RPMs
    NVIDIA_RPM=$(ls /var/cache/rpms/kmods/nvidia/nvidia-open-kmod-*.rpm | head -n 1)
    NVIDIA_AKMOD_VERSION=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "$NVIDIA_RPM" | sed "s/\.el.*//")
    # For kernel version, we can just use the running/target kernel?
    # Or checking what the kmod is built against?
    # In AlmaLinux, kmods utilize weak-modules so they work across minor kernel updates (kABI).
    # ensure we have VARS_KERNEL_VERSION set correctly from top.
    
else

# query latest available driver in repo
DRIVER_VERSION=$(dnf info akmod-nvidia | grep -E '^Version|^Release' | awk '{print $3}' | xargs | sed 's/\ /-/')

# only install the version of akmod-nviida which matches available nvidia-driver
# this works around situations where a new version may be released but not for one arch
dnf install -y \
    "akmod-nvidia-${DRIVER_VERSION}"

# Either successfully build and install the kernel modules, or fail early with debug output
rpm -qa |grep nvidia
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-nvidia" --queryformat '%{VERSION}-%{RELEASE}')" ".${DIST}")"

akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

modinfo /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/nvidia/"${NVIDIA_AKMOD_VERSION}"-for-"${KERNEL_VERSION}".failed.log && exit 1)

# View license information
modinfo -l /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# create a directory for later copying of resulting nvidia specific artifacts
mkdir -p /var/cache/rpms/kmods/nvidia

fi

# TODO: remove deprecated RELEASE var which clobbers more typical meanings/usages of RELEASE
cat <<EOF > /var/cache/rpms/kmods/nvidia-vars
DIST_ARCH="${DIST}.${ARCH}"
KERNEL_VERSION=${VARS_KERNEL_VERSION}
# KERNEL_MODULE_TYPE: deprecated as of 2025-12-07, in favor of KMOD_REPO
# latest drivers are always "open", and LTS driver is always "kernel"
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
# KMOD_REPO: latest drivers are "nvidia", and LTS driver is "nvidia-lts"
KMOD_REPO=${KMOD_REPO}
RELEASE="${DEPRECATED_RELEASE}"
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
EOF
