#!/usr/bin/bash
#shellcheck disable=SC2206

set "${CI:+-x}" -euo pipefail

dnf install -y dnf-plugins-core
pushd /tmp/kernel_cache
KERNEL_VERSION=$(find "$KERNEL_NAME"-*.rpm | grep "$(uname -m)" | grep -P "$KERNEL_NAME-\d+\.\d+\.\d+-\d+.*$(rpm -E '%{dist}')" | sed -E "s/$KERNEL_NAME-//;s/\.rpm//")
popd

### PREPARE REPOS
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]] || [[ "${KERNEL_FLAVOR}" =~ "almalinux" ]]; then
    echo "Building for CentOS/AlmaLinux"
    RELEASE="$(rpm -E '%centos')"
    mkdir -p /var/roothome
    RPM_PREP+=("https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RELEASE}.noarch.rpm")
    dnf config-manager --set-enabled crb
else
    echo "Building for Fedora"
    RELEASE="$(rpm -E '%fedora')"
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

# enable RPMs with alternatives to create them in this image build
mkdir -p /var/lib/alternatives

if [[ -f $(find /tmp/akmods-rpms/ublue-os/ublue-os-*.rpm 2> /dev/null) ]]; then
    RPM_PREP+=(/tmp/akmods-rpms/ublue-os/ublue-os-*.rpm)
fi

# install kernel_cache provided kernel
echo "Installing ${KERNEL_FLAVOR} kernel-cache RPMs..."
dnf install -y "${RPM_PREP[@]}" $(find /tmp/kernel_cache/*.rpm -type f | grep "$(uname -m)" | grep -v uki)

if [[ ! "${KERNEL_FLAVOR}" =~ "centos" ]] && [[ ! "${KERNEL_FLAVOR}" =~ "almalinux" ]]; then
    echo "Building for Fedora requires more repo setup"
    # enable more repos
    RPMFUSION_MIRROR_RPMS="https://mirrors.rpmfusion.org"
    if [ -n "${RPMFUSION_MIRROR}" ]; then
        RPMFUSION_MIRROR_RPMS=${RPMFUSION_MIRROR}
    fi
    RPM_PREP_EXTRA+=(
        "${RPMFUSION_MIRROR_RPMS}"/free/fedora/rpmfusion-free-release-"${RELEASE}".noarch.rpm
        "${RPMFUSION_MIRROR_RPMS}"/nonfree/fedora/rpmfusion-nonfree-release-"${RELEASE}".noarch.rpm
        fedora-repos-archive
    )

    # after F44 launches, bump to 45
    if [[ "${RELEASE}" -ge 44 ]]; then
        COPR_RELEASE="raxhwide"
    else
        COPR_RELEASE="${RELEASE}"
    fi

    curl -Lo /etc/yum.repos.d/_copr_ublue-os_staging.repo \
        "https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-${COPR_RELEASE}/ublue-os-staging-fedora-${COPR_RELEASE}.repo"
    curl -Lo /etc/yum.repos.d/_copr_kylegospo_oversteer.repo \
        "https://copr.fedorainfracloud.org/coprs/kylegospo/oversteer/repo/fedora-${COPR_RELEASE}/kylegospo-oversteer-fedora-${COPR_RELEASE}.repo"
    curl -Lo /etc/yum.repos.d/_copr_ublue-os-akmods.repo \
        "https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-${COPR_RELEASE}/ublue-os-akmods-fedora-${COPR_RELEASE}.repo"
    curl -Lo /etc/yum.repos.d/negativo17-fedora-multimedia.repo \
        "https://negativo17.org/repos/fedora-multimedia.repo"
    
    dnf install -y "${RPM_PREP_EXTRA[@]}"
fi

# after F44 launches, bump to 45
if [[ "${RELEASE}" -ge 44 && -f /etc/fedora-release ]]; then
    # pre-release rpmfusion is in a different location
    sed -i "s%free/fedora/releases%free/fedora/development%" /etc/yum.repos.d/rpmfusion-*.repo
    # pre-release rpmfusion needs to enable testing
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/rpmfusion-*-updates-testing.repo
fi

if [[ -n "${RPMFUSION_MIRROR}" && -f /etc/fedora-release ]]; then
    # force use of single rpmfusion mirror
    echo "Using single rpmfusion mirror: ${RPMFUSION_MIRROR}"
    sed -i.bak "s%^metalink=%#metalink=%" /etc/yum.repos.d/rpmfusion-*.repo
    sed -i "s%^#baseurl=http://download1.rpmfusion.org%baseurl=${RPMFUSION_MIRROR}%" /etc/yum.repos.d/rpmfusion-*.repo
fi

dnf install -y openssl

if [[ ! -s "/tmp/certs/private_key.priv" ]]; then
    echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
    cp /tmp/certs/public_key.der{.test,}
fi

openssl x509 -in /tmp/certs/public_key.der -out /tmp/certs/public_key.crt
cat /tmp/certs/public_key.crt > /tmp/certs/public_key_chain.pem
rm -f /tmp/certs/private_key.priv

if [[ "${DUAL_SIGN}" == "true" ]]; then
    if [[ ! -s "/tmp/certs/private_key_2.priv" ]]; then
        echo "WARNING: Using test signing key. Run './generate-akmods-key' for production builds."
        cp /tmp/certs/public_key_2.der{.test,}
    fi
    openssl x509 -in /tmp/certs/public_key_2.der -out /tmp/certs/public_key_2.crt
    rm -f /tmp/certs/public_key_chain.pem
    cat /tmp/certs/public_key.crt <(echo) /tmp/certs/public_key_2.crt >> /tmp/certs/public_key_chain.pem
fi

rm -f /tmp/certs/private_key_2.priv

if [[ -f $(find /tmp/akmods-rpms/kmods/zfs/kmod-*.rpm 2> /dev/null) ]]; then
    KMODS_TO_INSTALL+=(
        pv
        /tmp/akmods-rpms/kmods/zfs/*.rpm
    )
else
    # For common akmods, only install kmod-* packages (pre-built modules)
    # akmod-* packages require *-kmod-common subpackages that aren't built
    KMODS_TO_INSTALL+=($(find /tmp/akmods-rpms/kmods/ -name "kmod-*.rpm" -type f))
fi

dnf install -y --setopt=install_weak_deps=False "${KMODS_TO_INSTALL[@]}"

printf "KERNEL_NAME=%s" "$KERNEL_NAME" >> /tmp/info.sh
