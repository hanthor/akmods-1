#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

if [[ "${DUAL_SIGN}" != "true" ]]; then
    echo "Not Dual Signing..."
    exit 0
fi



if ! rpm -q "${KERNEL_NAME}" &>/dev/null; then
    # Fallback to kernel-core if the metapackage is missing (common on AlmaLinux/CentOS)
    if rpm -q kernel-core &>/dev/null; then
        KERNEL_NAME="kernel-core"
    fi
fi
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
SIGNING_KEY_1="/tmp/certs/signing_key_1.pem"
SIGNING_KEY_2="/tmp/certs/signing_key_2.pem"
PUBLIC_CHAIN="/tmp/certs/public_key_chain.pem"

shopt -s nullglob
for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*; do
    module_basename=${module:0:-3}
    module_suffix=${module: -3}
    if [[ "$module_suffix" == ".xz" ]]; then
        xz --decompress "$module"
        openssl cms -sign -signer "${SIGNING_KEY_1}" -signer "${SIGNING_KEY_2}" -binary -in "$module_basename" -outform DER -out "${module_basename}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module_basename}.cms" sha256 "${PUBLIC_CHAIN}" "${module_basename}"
        /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
        xz -C crc32 -f "${module_basename}"
    elif [[ "$module_suffix" == ".gz" ]]; then
        gzip -d "$module"
        openssl cms -sign -signer "${SIGNING_KEY_1}" -signer "${SIGNING_KEY_2}" -binary -in "$module_basename" -outform DER -out "${module_basename}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module_basename}.cms" sha256 "${PUBLIC_CHAIN}" "${module_basename}"
        /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
        gzip -9f "${module_basename}"
    else
        openssl cms -sign -signer "${SIGNING_KEY_1}" -signer "${SIGNING_KEY_2}" -binary -in "$module" -outform DER -out "${module}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module}.cms" sha256 "${PUBLIC_CHAIN}" "${module}"
        /tmp/dual-sign-check.sh "${KERNEL}" "${module}" "${PUBLIC_CHAIN}"
    fi
done
find /var/cache/akmods -type f -name "\kmod-*.rpm"
pushd /var/cache/akmods
mapfile -t RPMPATHS < <(find . -type f -name "\kmod-*.rpm")
for RPMPATH in "${RPMPATHS[@]}"; do
    RPM=$(basename "${RPMPATH/\.rpm/}")
    mkdir -p /tmp/buildroot
    cp -r /{usr,lib} /tmp/buildroot
    rpmrebuild --additional=--buildroot=/tmp/buildroot --batch "$RPM"
    rm -rf /tmp/buildroot
done
popd
rm -rf /usr/lib/modules/"${KERNEL}"/extra

# on CentOS, akmods/rpmbuild seems to mangle kernel version in the kmod package name
RPMS_DIR="/root/rpmbuild/RPMS/$(uname -m)"
if [[ -d "${RPMS_DIR}" ]]; then
    pushd "${RPMS_DIR}"
    mapfile -t RPMPATHS < <(find . -type f -name "\kmod-*.rpm")
    for RPMPATH in "${RPMPATHS[@]}"; do
        RPM=$(basename "${RPMPATH/\.rpm/}")
        if [[ ! "$RPM" =~ ${KERNEL} ]]; then
            RENAME=${RPM%"$(rpm -q --queryformat="%{VERSION}" kernel)"*}
            RENAME+=$KERNEL
            RENAME+=${RPM#*"$(rpm -E %dist)"}
            RPM_RENAME="$(dirname "$RPMPATH")/$RENAME.rpm"
            mv "$RPMPATH" "$RPM_RENAME"
        fi
    done
    # Reinstall KMODs for initial check that they were signed
    mapfile -t kmods < <(find . -maxdepth 1 -name "kmod-*.rpm" -type f)
    if [[ ${#kmods[@]} -gt 0 ]]; then
        dnf reinstall -y --allowerasing "${kmods[@]}"
    fi
    popd
fi
for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*; do
    if ! modinfo "${module}" >/dev/null; then
        exit 1
    fi
done
