#!/bin/bash
# System Hardening Script
# Applies security hardening to the system
# Requires root/sudo

echo "========================================"
echo "SYSTEM HARDENING"
echo "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "[1/5] Checking for suspicious files..."
for f in /tmp/*.so /tmp/*.elf; do
    if [ -f "$f" ]; then
        echo "Found: $f - removing..."
        rm -f "$f"
    fi
done
echo "✅ Temporary files check complete"

echo ""
echo "[2/5] Creating SSH hardening config..."
cat > /tmp/sshd_security_fix.cfg << 'EOF'
# SSH Hardening Configuration
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords no
EOF
echo "   ✅ Config created at /tmp/sshd_security_fix.cfg"

echo ""
echo "[3/5] Creating sysctl hardening config..."
cat > /tmp/sysctl_security.conf << 'EOF'
# Kernel Security Hardening
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.unprivileged_bpf_disabled = 1
EOF
echo "   ✅ Config created at /tmp/sysctl_security.conf"

echo ""
echo "[4/5] Applying sysctl settings..."
cp /tmp/sysctl_security.conf /etc/sysctl.d/99-security.conf
sysctl --system > /dev/null 2>&1
echo "✅ Sysctl hardening applied"

echo ""
echo "[5/5] Disabling unnecessary services..."
# Disable AnyDesk if present
if systemctl is-active --quiet anydesk 2>/dev/null; then
    systemctl stop anydesk
    systemctl disable anydesk
    echo "   ✅ AnyDesk disabled"
fi
echo "✅ Service hardening complete"

echo ""
echo "========================================"
echo "HARDENING COMPLETE"
echo "========================================"
echo ""
echo "To apply SSH hardening:"
echo "  cp /tmp/sshd_security_fix.cfg /etc/ssh/sshd_config"
echo "  systemctl restart ssh"
echo ""
echo "Verify settings with:"
echo "  sysctl net.ipv4.icmp_echo_ignore_all"
echo "  sysctl kernel.unprivileged_bpf_disabled"