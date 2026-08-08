#!/bin/bash
# Security Patch Helper Script
# Shows available patches and how to apply them

echo "========================================"
echo "SECURITY PATCHES AVAILABLE"
echo "========================================"

PATCH_DIR="$(dirname "$0")"

echo ""
echo "Patches:"
for patch in "$PATCH_DIR"/*.patch; do
    if [ -f "$patch" ]; then
        basename "$patch"
    fi
done

echo ""
echo "========================================"
echo "PATCH SUMMARY"
echo "========================================"
echo ""
echo "1. CVE-2026-31431 (Copy Fail) - HIGH"
echo "   Local Privilege Escalation via page cache"
echo "   Status: Already mitigated via module blacklist"
echo "   Patch: CVE-2026-31431-copy-fail.patch"
echo ""
echo "2. CVE-2026-31589 (folio_unmap) - CRITICAL"
echo "   Use-after-free in memory management"
echo "   Patch: CVE-2026-31589-folio-unmap-uaf.patch"
echo ""
echo "3. CVE-2026-31649 (stmmac) - CRITICAL"
echo "   Integer underflow in Ethernet driver"
echo "   Patch: CVE-2026-31649-stmmac-integer-underflow.patch"
echo ""
echo "4. CVE-2026-31533 (TLS) - HIGH"
echo "   Use-after-free in TLS subsystem"
echo "   Patch: CVE-2026-31533-tls-uaf.patch"
echo ""
echo "5. CVE-2026-31408 (Bluetooth) - MEDIUM"
echo "   Use-after-free in Bluetooth SCO"
echo "   Patch: CVE-2026-31408-bluetooth-sco-uaf.patch"
echo ""

echo "========================================"
echo "USAGE"
echo "========================================"
echo ""
echo "To apply patches to kernel sources:"
echo "  1. Get kernel sources:"
echo "     apt-get source linux-image-\$(uname -r)"
echo ""
echo "  2. Apply patches:"
echo "     cd /path/to/kernel/sources"
echo "     patch -p1 < /path/to/CVE-XXXX-XXXXX.patch"
echo ""
echo "  3. Build and install:"
echo "     make -j\$(nproc)"
echo "     sudo make modules_install"
echo "     sudo make install"
echo "     sudo update-grub"
echo ""
echo "========================================"

# Show current mitigation status
echo "Current Mitigation Status:"
echo ""

if [ -f /etc/modprobe.d/disable-algif-cve2026.conf ]; then
    echo "✅ CVE-2026-31431: MITIGATED"
    cat /etc/modprobe.d/disable-algif-cve2026.conf
else
    echo "⚠️  CVE-2026-31431: NOT MITIGATED"
fi

echo ""
echo "Kernel version:"
uname -r

echo ""
echo "========================================"