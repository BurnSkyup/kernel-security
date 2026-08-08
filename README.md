# Linux Kernel Security — CVE Patch Analysis & Hardening

My workspace for analyzing public Linux kernel vulnerabilities (2025–2026),
verifying and organizing their patches, and building a hardened custom
kernel for Debian-based distributions (ParrotOS, Kali, Ubuntu).

Patches and vulnerability details are based on public sources: upstream
kernel commits, NVD entries, and the original researchers' disclosures
(see References). My own work here is the analysis, verification,
hardening configuration, and tooling — see
[ANALYSIS.md](ANALYSIS.md) for my per-CVE root-cause notes.

---

## 🔍 CVE Root-Cause Analysis

[ANALYSIS.md](ANALYSIS.md) — my working notes for each CVE: affected
component, root cause, fix pattern, exploitability, and defensive
takeaways. Covered so far:

| CVE | CVSS | Type | Bug class |
|-----|------|------|-----------|
| CVE-2026-31589 | 9.8 | UAF in `folio_unmap_invalidate` | Use after lock release |
| CVE-2026-31649 | 9.8 | stmmac integer underflow | Unsigned wrap → DMA overmap |
| CVE-2026-31431 | 7.8 | algif_aead "Copy Fail" LPE | In-place op complexity (fix: revert) |
| CVE-2026-31533 | 7.8 | TLS UAF | Sync/async double cleanup |
| CVE-2026-31408 | 5.5 | Bluetooth SCO UAF | Missing refcount after unlock |

---

## 🛡️ Hardened Kernel Build (6.19.13)

Hardened Linux kernel configuration with 27+ security mitigations enabled,
Dirty Frag LPE mitigated, and the CVE patch series above applied.

### Hardening Applied

| Category | Options |
|----------|---------|
| **Memory Safety** | `INIT_ON_FREE_DEFAULT_ON`, `ZERO_CALL_USED_REGS`, `SHUFFLE_PAGE_ALLOCATOR`, `SLAB_FREELIST_HARDENED`, `RANDSTRUCT_PERFORMANCE` |
| **Module Security** | `MODULE_SIG_FORCE`, `MODULE_SIG_ALL`, `MODULE_SIG_SHA512` |
| **Kernel Lockdown** | `LOCK_DOWN_KERNEL_FORCE_INTEGRITY` |
| **CPU Mitigations** | SLS, RETBLEED, SRSO, GDS, RFDS, Spectre BHI, MMIO Stale Data |
| **Scheduler** | BORE + CachyOS optimizations |
| **Access Control** | `SECURITY_DMESG_RESTRICT`, `STRICT_DEVMEM`, `IO_STRICT_DEVMEM` |
| **Attack Surface** | `NET_SCH_QFQ` disabled (CVE-2026-22976), `INET_DIAG_DESTROY` disabled |

### Additional CVEs Mitigated via Config

| CVE | CVSS | Type | Mitigation |
|-----|------|------|------------|
| **Dirty Frag** (no CVE) | ~9.0 | LPE via xfrm-ESP + RxRPC page-cache write | Module blacklist + SKBFL_SHARED_FRAG patch |
| CVE-2026-22976 | 5.5 | NULL deref in sch_qfq | Module disabled (`NET_SCH_QFQ=n`) |
| CVE-2025-37916 | 7.8 | UAF in pds_core | Module not built |
| CVE-2025-38179 | 7.8 | OOB in cifs | `CIFS_SMB_DIRECT` not set |
| CVE-2026-23171 | 7.8 | UAF in bonding | Module not built |
| CVE-2026-23198 | 7.8 | UAF in KVM | Module not built |
| CVE-2026-23336 | 7.8 | UAF in cfg80211 | Module not built |
| CVE-2026-31494 | 7.8 | OOB in macb | Module not built |

Full CVE tracking: [kernel-6.19-custom/CVE-TRACKING.md](kernel-6.19-custom/CVE-TRACKING.md)

### Hardening Comparison

How this config compares against major distro kernels:

| Hardening Option | This Kernel 6.19 | Solus LTS 6.18 | Debian 6.12 |
|---|---|---|---|
| **CPU Mitigations (24)** | ✅ All | ✅ All | ✅ All |
| **Struct Randomization** | ✅ PERFORMANCE | ❌ NONE | ❌ NONE |
| **Module Signing (Force)** | ✅ SHA-512 | ❌ | ❌ |
| **Kernel Lockdown** | ✅ INTEGRITY | ❌ | ❌ |
| **INIT_ON_FREE** | ✅ Zero on kfree | ❌ | ❌ |
| **ZERO_CALL_USED_REGS** | ✅ | ❌ | ❌ |
| **DMESG_RESTRICT** | ✅ | ❌ | ❌ |
| **IO_STRICT_DEVMEM** | ✅ | ❌ | ❌ |
| **Dirty Frag LPE** | ✅ Mitigated | ❌ Vulnerable | ❌ Vulnerable |

> Solus comparison based on [PR #8790](https://github.com/getsolus/packages/pull/8790) (linux-lts 6.18.28).

### Build from Source

```bash
# Get kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.tar.xz
tar xf linux-6.19.tar.xz
cd linux-6.19

# Apply the hardened config
cp configs/defconfig .config
make olddefconfig

# Apply NVIDIA compat patch (if using NVIDIA proprietary driver)
patch -p1 < ../nvidia-compat-mutex_destroy.patch

# Build
make -j$(nproc)
sudo make modules_install
sudo make install
sudo update-grub
```

### Kernel Config

- [configs/defconfig](configs/defconfig) — boot config (minimal, what ships in /boot)
- [configs/defconfig-full](configs/defconfig-full) — full config with all options
- [configs/dirtyfrag.conf](configs/dirtyfrag.conf) — module blacklist for Dirty Frag mitigation

---

## 🔧 CVE Patches

| File | CVE | Severity | Description |
|------|-----|----------|-------------|
| `CVE-2026-31431-copy-fail.patch` | CVE-2026-31431 | HIGH (7.8) | Copy Fail — LPE via page cache |
| `CVE-2026-31589-folio-unmap-uaf.patch` | CVE-2026-31589 | CRITICAL (9.8) | UAF in folio_unmap_invalidate |
| `CVE-2026-31649-stmmac-integer-underflow.patch` | CVE-2026-31649 | CRITICAL (9.8) | Integer underflow in stmmac Ethernet driver |
| `CVE-2026-31533-tls-uaf.patch` | CVE-2026-31533 | HIGH (7.8) | UAF in TLS subsystem |
| `CVE-2026-31408-bluetooth-sco-uaf.patch` | CVE-2026-31408 | MEDIUM (5.5) | UAF in Bluetooth SCO |
| `nvidia-compat-mutex_destroy.patch` | N/A (compat) | — | Export `mutex_destroy` as non-GPL for NVIDIA DKMS |

### Apply Patches

```bash
git clone https://github.com/BurnSkyup/kernel-security.git
cd kernel-security

# Download kernel source
apt-get source linux-image-$(uname -r)

# Apply patches
chmod +x apply-kernel-fixes.sh
./apply-kernel-fixes.sh /path/to/kernel/source

# Build and install
cd /path/to/kernel/source
make -j$(nproc)
sudo make modules_install
sudo make install
sudo update-grub
sudo reboot
```

---

## 🛡️ System Hardening

```bash
chmod +x apply-fixes-immediate.sh
sudo ./apply-fixes-immediate.sh
```

Hardening applied:
- Disable ICMP echo (stealth mode)
- SSH hardening (key-based auth, no root login)
- Service lockdown (disable unused remote services)
- Network hardening (disable source routing, redirects)
- Kernel sysctl security (kptr_restrict, dmesg_restrict, bpf disabled)

### Security Verification

```bash
uname -r                           # Should show 6.19.13+
cat /etc/modprobe.d/dirtyfrag.conf # Dirty Frag blocked
sysctl kernel.unprivileged_bpf_disabled  # = 1
sysctl kernel.kptr_restrict              # = 2
sysctl kernel.dmesg_restrict             # = 1
```

---

## Files Structure

```
├── ANALYSIS.md                # My per-CVE root-cause analysis notes
├── configs/
│   ├── defconfig              # Kernel boot config (hardened)
│   ├── defconfig-full         # Full kernel config
│   └── dirtyfrag.conf         # Dirty Frag module blacklist
├── kernel-6.19-custom/
│   ├── CVE-TRACKING.md        # Complete CVE audit for custom kernel
│   └── CHANGELOG.md           # Build changelog
├── CVE-2026-31431-copy-fail.patch
├── CVE-2026-31589-folio-unmap-uaf.patch
├── CVE-2026-31649-stmmac-integer-underflow.patch
├── CVE-2026-31533-tls-uaf.patch
├── CVE-2026-31408-bluetooth-sco-uaf.patch
├── nvidia-compat-mutex_destroy.patch  # NVIDIA DKMS compat (EXPORT_SYMBOL)
├── apply-kernel-fixes.sh              # Kernel patch applicator
├── apply-fixes-immediate.sh           # System hardening
├── apply-security-patches.sh          # Security-only patcher
├── apply-system-hardening.sh          # Full system hardening
├── system-security-analyzer.sh        # Security analysis tool
├── INFORME_ANALISIS_SISTEMA.md        # System analysis (ES)
├── INFORME_COMPLETO_VULNERABILIDADES.md # Vulnerability report (ES)
└── README.md
```

## References

- [NVD — National Vulnerability Database](https://nvd.nist.gov/)
- [Linux Kernel Mailing List](https://lkml.org/)
- [Dirty Frag Disclosure](https://github.com/V4bel/dirtyfrag)
- [Kernel Self Protection Project](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project)
- [CERT-EU Security Advisories](https://cert.europa.eu/publications/security-advisories/)

## License

MIT License — Free to use, modify, and distribute.

## Disclaimer

Patches provided as-is for research and defensive hardening purposes.
Always backup before applying kernel updates. Test in a VM/sandbox before
deploying to production.

---
**Last Updated**: 2026-08-08 — **Kernel**: 6.19.13 hardened custom build · 6.12.x patch series
