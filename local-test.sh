#!/usr/bin/bash
# Local test script to catch CI failures before pushing
# Run this before pushing changes to verify builds work correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
KERNEL="${AKMODS_KERNEL:-almalinux}"
VERSION="${AKMODS_VERSION:-10}"
TARGET="${AKMODS_TARGET:-common}"
CLEAN_CACHE="${CLEAN_CACHE:-false}"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Test akmods builds locally before pushing to CI.

Options:
    -k, --kernel KERNEL    Kernel flavor (default: almalinux)
    -v, --version VERSION  Version (default: 10)
    -t, --target TARGET    Build target: common, zfs (default: common)
    -c, --clean           Clean Podman cache before building
    -h, --help            Show this help

Environment Variables:
    AKMODS_KERNEL, AKMODS_VERSION, AKMODS_TARGET - same as options

Examples:
    $0                                    # Test common akmods for AlmaLinux 10
    $0 -t zfs                             # Test ZFS akmods
    $0 -k fedora -v 41 -t common          # Test for Fedora 41
    $0 -c                                 # Clean cache and rebuild
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--kernel) KERNEL="$2"; shift 2 ;;
        -v|--version) VERSION="$2"; shift 2 ;;
        -t|--target) TARGET="$2"; shift 2 ;;
        -c|--clean) CLEAN_CACHE="true"; shift ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/test-logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_LOG="${LOG_DIR}/build_${KERNEL}_${VERSION}_${TARGET}_${TIMESTAMP}.log"
TEST_LOG="${LOG_DIR}/test_${KERNEL}_${VERSION}_${TARGET}_${TIMESTAMP}.log"

log_info "Testing akmods build for: ${KERNEL}-${VERSION} (target: ${TARGET})"
log_info "Build log: ${BUILD_LOG}"
log_info "Test log: ${TEST_LOG}"

# Clean cache if requested
if [[ "$CLEAN_CACHE" == "true" ]]; then
    log_warn "Cleaning Podman cache..."
    podman image prune -af 2>/dev/null || true
fi

# Clean previous build artifacts
log_info "Cleaning previous build artifacts..."
just clean 2>/dev/null || true

# Set environment
export AKMODS_KERNEL="$KERNEL"
export AKMODS_VERSION="$VERSION"
export AKMODS_TARGET="$TARGET"

# Run build
log_info "Starting build..."
BUILD_START=$(date +%s)
if just build 2>&1 | tee "$BUILD_LOG"; then
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    log_info "Build completed in ${BUILD_TIME}s"
else
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    log_error "Build FAILED after ${BUILD_TIME}s"
    log_error "Check build log: ${BUILD_LOG}"
    
    # Show relevant errors
    echo ""
    log_error "=== Build Errors ==="
    grep -i -E "(error|failed|undefined|not found)" "$BUILD_LOG" | tail -20 || true
    exit 1
fi

# Check for built RPMs
log_info "Checking built artifacts..."
if grep -q "Wrote:.*\.rpm" "$BUILD_LOG"; then
    log_info "Built RPMs:"
    grep "Wrote:.*\.rpm" "$BUILD_LOG" | sed 's/.*Wrote: /  - /' | tail -20
else
    log_warn "No RPM files found in build output"
fi

# Run tests
log_info "Starting test..."
TEST_START=$(date +%s)
if just test 2>&1 | tee "$TEST_LOG"; then
    TEST_END=$(date +%s)
    TEST_TIME=$((TEST_END - TEST_START))
    log_info "Tests PASSED in ${TEST_TIME}s"
else
    TEST_END=$(date +%s)
    TEST_TIME=$((TEST_END - TEST_START))
    log_error "Tests FAILED after ${TEST_TIME}s"
    log_error "Check test log: ${TEST_LOG}"
    
    # Show relevant errors
    echo ""
    log_error "=== Test Errors ==="
    grep -i -E "(error|failed|undefined|not found|nothing provides)" "$TEST_LOG" | tail -20 || true
    exit 1
fi

# Summary
echo ""
log_info "=== Summary ==="
log_info "Target: ${KERNEL}-${VERSION} (${TARGET})"
log_info "Build time: ${BUILD_TIME}s"
log_info "Test time: ${TEST_TIME}s"
log_info "Build log: ${BUILD_LOG}"
log_info "Test log: ${TEST_LOG}"
echo ""
log_info "All tests passed! Safe to push."
