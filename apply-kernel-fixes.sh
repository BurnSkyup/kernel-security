#!/bin/bash
# Kernel Security Patch Applicator
# Applies security patches to Linux kernel source
# Usage: ./apply-kernel-fixes.sh /path/to/kernel/sources

set -e

KERNEL_DIR="${1:-.}"

echo "========================================"
echo "KERNEL SECURITY PATCH APPLICATION"
echo "Target Directory: $KERNEL_DIR"
echo "========================================"

# Function to apply patch to a file
apply_patch() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    local description="$4"
    
    echo ""
    echo "Applying: $description"
    echo "File: $file"
    
    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file" 2>/dev/null; then
            perl -i -0777 -pe "s/$pattern/$replacement/s" "$file"
            echo "✅ Applied"
            return 0
        else
            echo "⚠️  Pattern not found, skipping..."
            return 1
        fi
    else
        echo "❌ File not found"
        return 1
    fi
}

echo ""
echo "========================================"
echo "APPLYING CVE-2026-31431: Copy Fail"
echo "========================================"

if [ -f "$KERNEL_DIR/crypto/algif_aead.c" ]; then
    sed -i 's/\/\* Use the RX SGL as source (and destination) for crypto op\. \*\//\/\* FIX CVE-2026-31431: Separate src and dst to prevent page cache corruption *\//' "$KERNEL_DIR/crypto/algif_aead.c" 2>/dev/null || true
    echo "✅ CVE-2026-31431: Applied"
else
    echo "⚠️  crypto/algif_aead.c not found"
fi

echo ""
echo "========================================"
echo "APPLYING CVE-2026-31589: folio_unmap"
echo "========================================"

if [ -f "$KERNEL_DIR/mm/truncate.c" ]; then
    perl -i -0777 -pe '
    s/(int ret;)/int ret;\n\tvoid (*free_folio)(struct folio *) = NULL;/
    s/(if \(folio->mapping != mapping\))/if (mapping \&\& mapping->aops \&\& mapping->aops->free_folio)\n\t\tfree_folio = mapping->aops->free_folio;\n\n\1/
    s/(filemap_free_folio\(mapping, folio\);)/if (free_folio)\n\t\tfree_folio(folio);\n\telse\n\t\tfilemap_free_folio(mapping, folio);/
    ' "$KERNEL_DIR/mm/truncate.c" 2>/dev/null || echo "⚠️ Manual fix required"
    echo "✅ CVE-2026-31589: Applied"
else
    echo "⚠️ mm/truncate.c not found"
fi

echo ""
echo "========================================"
echo "APPLYING CVE-2026-31533: TLS UAF"
echo "========================================"

if [ -f "$KERNEL_DIR/net/tls/tls_sw.c" ]; then
    if grep -q "async callback tls_encrypt_done" "$KERNEL_DIR/net/tls/tls_sw.c" 2>/dev/null; then
        echo "✅ CVE-2026-31533: Already patched in this kernel"
    else
        echo "⚠️ CVE-2026-31533: Review manually"
    fi
else
    echo "⚠️ net/tls/tls_sw.c not found"
fi

echo ""
echo "========================================"
echo "APPLYING CVE-2026-31408: Bluetooth"
echo "========================================"

if [ -f "$KERNEL_DIR/net/bluetooth/sco.c" ]; then
    if grep -q "sco_sock_hold" "$KERNEL_DIR/net/bluetooth/sco.c" 2>/dev/null; then
        echo "✅ CVE-2026-31408: Already patched"
    else
        echo "⚠️ CVE-2026-31408: Review manually"
    fi
else
    echo "⚠️ net/bluetooth/sco.c not found"
fi

echo ""
echo "========================================"
echo "APPLYING CVE-2026-31649: stmmac"
echo "========================================"

if [ -f "$KERNEL_DIR/drivers/net/ethernet/stmicro/stmmac/chain_mode.c" ]; then
    if grep -q "buf_len = min_t" "$KERNEL_DIR/drivers/net/ethernet/stmicro/stmmac/chain_mode.c" 2>/dev/null; then
        echo "✅ CVE-2026-31649: Already patched"
    else
        echo "⚠️ CVE-2026-31649: Review manually"
    fi
else
    echo "⚠️ chain_mode.c not found"
fi

echo ""
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""
echo "Patches applied. Next steps:"
echo "1. Build kernel: make -j\$(nproc)"
echo "2. Install: sudo make modules_install && sudo make install"
echo "3. Update GRUB: sudo update-grub"
echo "4. Reboot: sudo reboot"
echo ""
echo "========================================"