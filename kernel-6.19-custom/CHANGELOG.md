# Kernel 6.19.13.parrot.custom+2.0 — Build Changelog

## Build #8 (2026-05-12) — v2.0 Release

### New Features
- **CachyOS scheduling**: enabled BORE scheduler + CachyOS CPU optimizations
- **LOCALVERSION**: `.parrot.custom+2.0-cachyos`

### Bugfix: NVIDIA DKMS (mutex_destroy GPL symbol)
- **Patch**: `EXPORT_SYMBOL_GPL(mutex_destroy)` → `EXPORT_SYMBOL(mutex_destroy)`
- **File**: `kernel/locking/mutex-debug.c`
- **Root cause**: kernel `6.19` marks `mutex_destroy` as GPL-only via `EXPORT_SYMBOL_GPL`
- **Fix**: changed to `EXPORT_SYMBOL` (non-GPL) for NVIDIA proprietary driver compatibility
- **Patch file**: `nvidia-compat-mutex_destroy.patch` in repo root

### DKMS Status
- `nvidia-current/550.163.01` — ✅ installed for new kernel
- `broadcom-sta/6.30.223.271` — ✅ installed for new kernel

### Networking
- Restored `INET_AH`, `INET_ESP`, `INET_ESP_OFFLOAD`, `INET_IPCOMP`
- Restored `INET_DIAG`, `INET_TCP_DIAG`, `INET_UDP_DIAG`, `INET_RAW_DIAG`
- Restored `IP_SCTP`, `RDS`, `TIPC` protocol support
- Added `INET_MPTCP_DIAG` for Multipath TCP diagnostics

### Build Environment
- GCC 14.2.0 (Debian)
- GNU ld 2.44 (Binutils)
- Build #6 (SMP PREEMPT_DYNAMIC)
- QEMU sandbox-tested: no panics, no oops

### Packages (Release 2.0)

| Package | Size |
|---------|------|
| `linux-image` | 292 MB |
| `linux-headers` | 11 MB |
| `linux-image-dbg` | 1.3 GB |
| `linux-libc-dev` | 1.5 MB |

## Build #5 (2026-05-07)

### Security Patches
- **Dirty Frag LPE fix**: SKBFL_SHARED_FRAG flag for xfrm-ESP splice path (commit `f4c50a4034` from netdev)
- RxRPC: already mitigated in 6.19.13 (code path rewritten)

### Module Blacklist
- `/etc/modprobe.d/dirtyfrag.conf`: block `esp4`, `esp6`, `rxrpc` from loading

## Build #4 (2026-05-07)

### Hardening Config

| Option | Value | Effect |
|--------|-------|--------|
| `INIT_ON_FREE_DEFAULT_ON` | y | Zero memory on kfree |
| `ZERO_CALL_USED_REGS` | y | Zero CPU registers before return |
| `MODULE_SIG_FORCE` | y | Block unsigned kernel modules |
| `MODULE_SIG_ALL` | y | Auto-sign all modules |
| `MODULE_SIG_SHA512` | y | SHA-512 for module signatures |
| `RANDSTRUCT_PERFORMANCE` | y | Randomize kernel struct layouts |
| `GCC_PLUGIN_RANDSTRUCT` | y | GCC plugin for struct randomization |
| `LOCK_DOWN_KERNEL_FORCE_INTEGRITY` | y | Kernel lockdown (integrity mode) |
| `MITIGATION_SLS` | y | Straight-Line Speculation |
| `MITIGATION_RETBLEED` | y | Retbleed mitigation |
| `MITIGATION_SRSO` | y | AMD SRSO mitigation |
| `MITIGATION_GDS` | y | Gather Data Sampling |
| `MITIGATION_RFDS` | y | RFDS mitigation |
| `MITIGATION_SPECTRE_BHI` | y | Spectre BHI |
| `MITIGATION_SPEC_STORE_BYPASS` | y | Speculative Store Bypass |
| `MITIGATION_MMIO_STALE_DATA` | y | MMIO Stale Data |
| `STRICT_DEVMEM` | y | Restrict /dev/mem |
| `IO_STRICT_DEVMEM` | y | Restrict I/O devmem |
| `SECURITY_DMESG_RESTRICT` | y | Restrict dmesg to root |
| `SCHED_CORE` | y | Core scheduling (L1TF/L2) |
| `SYN_COOKIES` | y | TCP SYN cookies |

### Attack Surface Reduction
- `NET_SCH_QFQ` disabled (CVE-2026-22976)
- `INET_DIAG_DESTROY` disabled
- `KCMP` attempted (re-enabled by CHECKPOINT_RESTORE dependency)

### Build Environment
- GCC 14.2.0 (Debian)
- GNU ld 2.44 (Binutils)
- Base config: Parrot OS 6.19 amd64 template

## Build #1 (2026-05-06)

### Initial Build
- Base: linux-6.19 tarball
- Config: Parrot OS template + customization
- LOCALVERSION: `.parrot.custom+1.0`
- iptables: legacy removed, nftables-only
- FIPS 140-2: removed
- Rust: stripped (RUSTC_VERSION=0)
- OpenVPN kernel module: removed
- Hyper-V: all removed
- UBSAN: all removed
