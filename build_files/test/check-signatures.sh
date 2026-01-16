#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

#shellcheck disable=SC1091
source /tmp/info.sh

if ! rpm -q "${KERNEL_NAME}" &>/dev/null; then
    # Fallback to kernel-core if the metapackage is missing (common on AlmaLinux/CentOS)
    if rpm -q kernel-core &>/dev/null; then
        KERNEL_NAME="kernel-core"
    fi
fi
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
PUBLIC_CHAIN="/tmp/certs/public_key_chain.pem"

for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*;
do
    module_basename=${module:0:-3}
    module_suffix=${module: -3}
    if [[ "$module_suffix" == ".xz" ]]; then
            xz --decompress "$module"
            /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
            xz -C crc32 -f "${module_basename}"
    elif [[ "$module_suffix" == ".gz" ]]; then
            gzip -d "$module"
            /tmp/dual-sign-check.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
            gzip -9f "${module_basename}"
    else
            /tmp/dual-sign-check.sh "${KERNEL}" "${module}" "${PUBLIC_CHAIN}"
    fi
done
