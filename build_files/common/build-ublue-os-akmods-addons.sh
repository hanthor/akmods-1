#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail


### BUILD UBLUE AKMODS-ADDONS RPM
# ensure a higher priority is set for our ublue akmods COPR to pull deps from it over other sources (99 is default)
REPO_FILE="/tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo"
NEG_REPO_FILE="/tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo"

mkdir -p "$(dirname "$REPO_FILE")"

if [ -f "$REPO_FILE" ]; then
    echo "priority=85" >> "$REPO_FILE"
else
    # Create dummy files for EL (CentOS/AlmaLinux) where these repos are skipped
    touch "$REPO_FILE"
fi

if [ ! -f "$NEG_REPO_FILE" ]; then
     touch "$NEG_REPO_FILE"
fi

install -D /etc/pki/akmods/certs/public_key.der /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/public_key.der
rpmbuild -ba \
    --define '_topdir /tmp/ublue-os-akmods-addons/rpmbuild' \
    --define '%_tmppath %{_topdir}/tmp' \
    /tmp/ublue-os-akmods-addons/ublue-os-akmods-addons.spec
