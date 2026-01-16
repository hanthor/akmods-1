#!/usr/bin/bash
set -euo pipefail

RPMBUILD_DIR="/root/rpmbuild"
mkdir -p "${RPMBUILD_DIR}"/{SOURCES,SPECS,RPMS,SRPMS,BUILD,BUILDROOT}

# Fetch sources for vendored specs
# Note: Use -C only, NOT -R (they conflict)
echo "Fetching sources for vendored specs..."

# Framework Laptop
echo "Processing framework-laptop-kmod.spec..."
spectool -g -C "${RPMBUILD_DIR}/SOURCES" "${RPMBUILD_DIR}/SPECS/framework-laptop-kmod.spec" || true
# spectool with fragment should create framework-laptop-kmod-main.tar.gz directly
if [ -f "${RPMBUILD_DIR}/SOURCES/main.tar.gz" ]; then
    mv "${RPMBUILD_DIR}/SOURCES/main.tar.gz" "${RPMBUILD_DIR}/SOURCES/framework-laptop-kmod-main.tar.gz"
fi

# Xone (uses master.tar.gz)
echo "Processing xone-kmod.spec..."
spectool -g -C "${RPMBUILD_DIR}/SOURCES" "${RPMBUILD_DIR}/SPECS/xone-kmod.spec" || true
if [ -f "${RPMBUILD_DIR}/SOURCES/master.tar.gz" ]; then
    mv "${RPMBUILD_DIR}/SOURCES/master.tar.gz" "${RPMBUILD_DIR}/SOURCES/xone-kmod-master.tar.gz"
fi

# OpenRazer (uses master.tar.gz)
echo "Processing openrazer-kmod.spec..."
spectool -g -C "${RPMBUILD_DIR}/SOURCES" "${RPMBUILD_DIR}/SPECS/openrazer-kmod.spec" || true
if [ -f "${RPMBUILD_DIR}/SOURCES/master.tar.gz" ]; then
    mv "${RPMBUILD_DIR}/SOURCES/master.tar.gz" "${RPMBUILD_DIR}/SOURCES/openrazer-kmod-master.tar.gz"
fi

# V4L2Loopback
echo "Processing v4l2loopback.spec..."
spectool -g -C "${RPMBUILD_DIR}/SOURCES" "${RPMBUILD_DIR}/SPECS/v4l2loopback.spec" || true

# Broadcom WL
echo "Processing broadcom-wl.spec..."
spectool -g -C "${RPMBUILD_DIR}/SOURCES" "${RPMBUILD_DIR}/SPECS/broadcom-wl.spec" || true

echo "Listing SOURCES after fetch:"
ls -lh "${RPMBUILD_DIR}/SOURCES"

# Ensure firmware/aux files are in place (already copied via Containerfile if in rpmbuild/SOURCES)


