#!/bin/bash
# Security Fixes - Immediate Application
# Apply security fixes without requiring rebuild

echo "========================================"
echo "APPLYING SECURITY FIXES"
echo "========================================"

# 1. Clean temporary files
echo ""
echo "[1/5] Verifying /tmp is clean..."
if ls /tmp/*.so 2>/dev/null; then
    rm -f /tmp/*.so 2>/dev/null
    echo "   ✅ Removed suspicious .so files"
else
    echo "   ✅ /tmp is clean"
fi

# 2. Create SSH hardening configuration
echo ""
echo "[2/5] Creating SSH hardening config..."
cat > /tmp/sshd_security_fix.cfg << 'EOF'
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
EOF
echo "   ✅ SSH config created at /tmp/sshd_security_fix.cfg"
echo "   ⚠️  To apply: sudo cp /tmp/sshd_security_fix.cfg /etc/ssh/sshd_config"

# 3. Create sysctl hardening config
echo ""
echo "[3/5] Creating sysctl hardening config..."
cat > /tmp/sysctl_security.conf << 'EOF'
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
echo "   ✅ Sysctl config created at /tmp/sysctl_security.conf"
echo "   ⚠️  To apply: sudo cp /tmp/sysctl_security.conf /etc/sysctl.d/99-security.conf && sudo sysctl -p"

# 4. Create service disable script
echo ""
echo "[4/5] Creating service management script..."
cat > /tmp/disable_risky_services.sh << 'EOF'
#!/bin/bash
# Disable risky services

echo "Disabling risky services..."

# Stop AnyDesk
if systemctl is-active --quiet anydesk 2>/dev/null; then
    echo "Stopping AnyDesk..."
    sudo systemctl stop anydesk
    sudo systemctl disable anydesk
fi

echo "Done!"
EOF
chmod +x /tmp/disable_risky_services.sh
echo "   ✅ Script created at /tmp/disable_risky_services.sh"
echo "   ⚠️  To apply: sudo /tmp/disable_risky_services.sh"

# 5. Create firewall recommendations
echo ""
echo "[5/5] Creating firewall recommendations..."
cat > /tmp/firewall_recommendations.sh << 'EOF'
#!/bin/bash

# Block AnyDesk port
sudo ufw deny 6568/tcp 2>/dev/null

# Block ADB port if not needed
sudo ufw deny 5037/tcp 2>/dev/null

echo "Done!"
EOF
chmod +x /tmp/firewall_recommendations.sh
echo "   ✅ Firewall script created"

echo ""
echo "========================================"
echo "FIXES GENERATED"
echo "========================================"
echo ""
echo "Files created:"
echo "  - /tmp/sshd_security_fix.cfg"
echo "  - /tmp/sysctl_security.conf"
echo "  - /tmp/disable_risky_services.sh"
echo "  - /tmp/firewall_recommendations.sh"
echo ""
echo "To apply fixes requiring sudo:"
echo "  1. sudo /tmp/disable_risky_services.sh"
echo "  2. sudo cp /tmp/sysctl_security.conf /etc/sysctl.d/99-security.conf"
echo "  3. sudo sysctl -p"
echo "  4. sudo cp /tmp/sshd_security_fix.cfg /etc/ssh/sshd_config"
echo "  5. sudo systemctl restart sshd"