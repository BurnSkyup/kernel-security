# Root-Cause Analysis Notes — Public Linux Kernel CVEs

These are my working notes from analyzing public Linux kernel vulnerability
patches. For each CVE: affected component, root cause, the fix pattern, and
defensive takeaways. Sources: public patches, NVD entries, and original
researcher disclosures (see README references).

---

## CVE-2026-31589 — UAF in `folio_unmap_invalidate()` (mm/filemap.c) — CVSS 9.8

**Root cause.** `folio_unmap_invalidate()` called `filemap_free_folio()`
after the folio had already been removed from the mapping. At that point the
folio no longer pins the `address_space`, so the mapping can be freed
concurrently — and accessing `mapping->a_ops` becomes a use-after-free.

**Fix pattern.** Follow the `__remove_mapping()` pattern: load the
`free_folio` function pointer *while still holding the mapping lock*, then
drop the lock and invoke the saved pointer. This also lets
`filemap_free_folio()` become `static` (no external callers left).

**Defensive takeaways.**
- Bug class: lock/lifetime ordering — the classic "use after lock release"
  pattern in page-cache code.
- Detection: KASAN on any kernel build exercising truncate/invalidate paths
  under memory pressure; syzkaller mm fuzzing reaches this.
- Triage hint: crashes showing `filemap_free_folio` / `->free_folio` in the
  stack with poisoned `mapping` pointer.

---

## CVE-2026-31649 — Integer underflow in stmmac chain mode (drivers/net/ethernet/stmicro/stmmac) — CVSS 9.8

**Root cause.** In `jumbo_frm()`, when a packet has a small linear portion
(`nopaged_len <= bmax`) but a large total length from page fragments
(`skb->len > bmax`), the subtraction `len = nopaged_len - bmax` wraps as an
unsigned integer (~0xFFFFxxxx). The `while (len != 0)` loop then runs
hundreds of thousands of iterations, passing `skb->data + bmax * i` pointers
far beyond the skb buffer to `dma_map_single()`.

**Impact.** On IOMMU-less SoCs (the typical stmmac deployment), this maps
arbitrary kernel memory to the DMA engine: kernel memory disclosure and
potential hardware-driven memory corruption.

**Fix pattern.** Clamp with `buf_len = min(nopaged_len, bmax)` so
`len = nopaged_len - buf_len` is always safe; when the linear part fits in
one descriptor, `len == 0` and the loop is skipped — the fragment path in
`stmmac_xmit()` handles the rest.

**Defensive takeaways.**
- Bug class: unsigned underflow feeding a loop bound + DMA mapping.
- Audit pattern: any `a - b` where `a` can be smaller than `b` feeding a
  loop or size argument in driver TX paths.
- Embedded/SoC kernels without IOMMU are the highest-risk targets.

---

## CVE-2026-31533 — UAF in TLS decryption error path (net/tls/tls_sw.c) — CVSS 7.8

**Root cause.** When `tls_do_encrypt()` returns `-EBUSY`, the crypto request
is queued to the cryptd backlog and the async callback `tls_encrypt_done()`
fires on completion. The old code *also* performed synchronous cleanup of
`ctx->encrypt_pending` and the scatterlist entries on the `-EBUSY` path —
cleanup the callback has already done or will do. A subsequent `recvmsg`
can free the `encrypt_pending` structure, and when the callback eventually
fires it operates on freed memory: use-after-free via double cleanup.

**Fix pattern.** On `-EBUSY`, skip the synchronous cleanup entirely — the
async callback owns `encrypt_pending` and sge restoration. Set an `async`
flag and `goto out`.

**Defensive takeaways.**
- Bug class: sync/async double cleanup — ownership of pending state must be
  exactly one of the two paths, never both.
- Audit pattern: search for `-EBUSY` handling where both the caller and the
  completion callback touch the same pending structure.
- kTLS sockets are reachable from unprivileged userspace — real LPE surface.

---

## CVE-2026-31408 — UAF in Bluetooth SCO `sco_recv_frame()` (net/bluetooth/sco.c) — CVSS 5.5

**Root cause.** `sco_recv_frame()` read `conn->sk` under `sco_conn_lock()`
but released the lock without holding a socket reference. A concurrent
`close()` could free the socket between lock release and the subsequent
`sk->sk_state` access — use-after-free.

**Fix pattern.** Use the same reference-counting pattern already used by
`sco_sock_timeout()` and `sco_conn_del()` in the same file: take
`sock_hold()` while the lock is held, only touch `sk->sk_state` if the
reference was acquired, and `sock_put()` on every exit path.

**Defensive takeaways.**
- Bug class: missing refcount after lock release.
- Audit pattern: "pointer read under lock, used after unlock" — grep for
  unlock followed by dereference of the protected pointer.
- The fix example was already present elsewhere in the same file — a common
  sign that one call site was simply missed.

---

## CVE-2026-31431 — "Copy Fail" LPE in algif_aead (crypto/algif_aead.c) — CVSS 7.8

**Root cause.** The in-place operation path added to `algif_aead` (commit
72548b093ee3) served no real purpose — source and destination come from
different mappings — and its scatterlist handling allowed an unprivileged
local user to perform a deterministic, controlled 4-byte write into the
page cache of any readable file.

**Impact.** Local privilege escalation to root; because page cache is
shared, this also enables container escape.

**Fix pattern.** Herbert Xu's revert: go back to operating out-of-place,
copy the associated data directly, and delete the in-place complexity
(~85 insertions / ~130 deletions across `algif_aead.c`, `af_alg.c`,
`algif_skcipher.c`, `if_alg.h`).

**Defensive takeaways.**
- Bug class: feature-complexity-induced memory corruption; the fix is a
  *revert*, not a band-aid — worth remembering when evaluating patch
  quality.
- AF_ALG sockets are unprivileged: any crypto API memory bug here is LPE
  grade by default.
- A 4-byte controlled page-cache write is a very strong primitive —
  overwriting setuid-binary pages is the canonical escalation path.

---

## Cross-CVE patterns (what I look for now)

1. **Lifetime vs. lock ordering** — 31589, 31408: pointer used after the
   lock/refcount protecting it is gone.
2. **Double cleanup across sync/async boundary** — 31533.
3. **Unsigned arithmetic feeding loops/DMA** — 31649.
4. **Complexity-induced corruption fixed by revert** — 31431.

These four classes cover most of the 2025–2026 LPE patch stream I have
reviewed so far, and they map directly onto the hardening options enabled
in the custom kernel build (see README): `INIT_ON_FREE_DEFAULT_ON`,
`SLAB_FREELIST_HARDENED`, and `SHUFFLE_PAGE_ALLOCATOR` all raise the cost
of exploiting classes 1–2.
