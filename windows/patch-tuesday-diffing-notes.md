# Windows Kernel Patch Tuesday Diffing — Methodology Notes

*Working notes on extracting root-cause information from Microsoft's monthly
security updates. Pure static-analysis workflow — no exploit development,
goal is understanding bug classes and building detection.*

---

## 1. Why diff Patch Tuesday

Microsoft publishes CVE identifiers with each security update but almost
never describes the actual bug. The binary diff between the pre-patch and
post-patch build of the affected component is usually the **only**
ground-truth description of what was wrong. For a defender, that diff
answers three questions that matter:

1. **What bug class** was fixed (overflow, UAF, TOCTOU, integer issue…)?
2. **Which code path** reaches it — i.e., what should telemetry watch?
3. **How would exploitation manifest** — which artifacts can a detection
   rule key on?

This is standard N-day analysis practice; everything here uses public
update packages and public symbols.

## 2. Inputs (all public)

| Source | What you get |
|---|---|
| [MSRC Security Update Guide](https://msrc.microsoft.com/update-guide) | CVE → affected component (e.g. `ntoskrnl.exe`, `win32kfull.sys`, `cldflt.sys`), KB number |
| [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/) | Downloadable `.msu` / `.cab` for the KB — both the last pre-patch and first post-patch monthly rollups |
| Microsoft public symbol server (`srv*https://msdl.microsoft.com/download/symbols`) | PDBs for both builds — function names make diffs readable |

Practical tip: pick the **cumulative rollup** pair (month N vs. month
N-1) for the same OS build. Delta packages are forward-differential;
starting from full rollups avoids having to reverse-integrate PSF patch
files (that is a whole topic of its own — tools like `PSFExtractor` exist
for when you can't avoid it).

## 3. Toolchain

| Task | Tool |
|---|---|
| Binary diffing | BinDiff (zynamics) or Diaphora (open source) — function-level matching between the two builds |
| Decompilation / reading | Ghidra (free) or IDA Pro |
| Symbols | `symchk` / WinDbg `.symfix` against the public symbol server |
| Kernel inspection | WinDbg (local static use; two-machine debug only if dynamic verification is ever needed) |
| Update extraction | `expand`, `7-zip`, optionally `PSFExtractor` for delta PSFs |

## 4. The workflow

1. **Select target.** From the MSRC entry, note the component named in
   the CVE (e.g. "Windows Kernel", "Win32k", "CLFS"). Elevation-of-
   Privilege CVEs in kernel components are the highest-value targets —
   they are the ones that matter for post-exploitation chains.
2. **Fetch both builds.** Download month N-1 and month N rollups from the
   catalog; extract the component binary from each
   (`Windows10.0-kbXXXXXXX-x64.cab` → payload files).
3. **Bind symbols.** Pull PDBs for both builds; load both into the
   differ.
4. **Diff.** BinDiff/Diaphora will match ~95% of functions 1:1. The
   interesting set is small: *matched functions with similarity < 1.0*.
   Monthly rollups touch little code, so typically only a handful of
   functions differ — and usually one of them changed *because of the
   CVE*, while others changed for unrelated servicing.
5. **Read the changed function.** Compare decompilation side by side.
   The fix almost always takes one of a handful of recognizable shapes
   (next section).
6. **Classify & write up.** Name the bug class, the attacker-controlled
   input that reaches it, and the detection surface. That write-up *is*
   the deliverable — it is what turns "I ran a diff" into research notes.

## 5. Recognizing fix shapes (field guide)

| Fix pattern in the diff | Likely bug class |
|---|---|
| New comparison against a constant before a `memcpy`/pool copy | Buffer/pool overflow — missing bounds check |
| Added `ObfReferenceObject` / `ExAcquireRundownProtection` before use | UAF / lifetime bug — missing refcount |
| New `ProbeForRead`/`ProbeForWrite` or `__try/__except` around user-pointer access | Missing user-mode pointer validation |
| Arithmetic replaced with `RtlULongAdd`/checked math, or new overflow branch | Integer overflow/underflow |
| Lock acquisition moved earlier / scope widened | TOCTOU race |
| Object type check added (`ObReferenceObjectByHandle` type arg changed) | Type confusion |
| Syscall now reads user buffer once into a local instead of twice | Double-fetch race |

One real-world pattern worth remembering: many kernel EoP fixes are
**one to five instructions**. If the diff shows a huge rewrite, you are
probably looking at unrelated refactoring — keep hunting in the other
changed functions.

## 6. From diff to defense

The point of the exercise. For each classified bug:

- **Telemetry**: which syscall/sysctl/interface reaches the vulnerable
  path? ETW providers (e.g. `Microsoft-Windows-Kernel-*`), audit
  policies, or EDR hooks can watch for anomalous call patterns.
- **Exploitation artifacts**: pool-corruption bugs leave predictable
  crash signatures (`POOL_CORRUPTION`, `BAD_POOL_HEADER`,
  `SYSTEM_SERVICE_EXCEPTION` with specific parameters). Documenting
  these signatures is directly reusable in triage runbooks.
- **Patch-gap analysis**: machines without the update are exposed for a
  known, understood bug — the diff write-up doubles as the urgency
  justification for patch deployment.

## 7. Current status & next steps

- [x] Methodology documented (this note)
- [ ] Apply the workflow to one concrete recent kernel EoP CVE end-to-end
      and publish the per-function diff walk-through as
      `windows/diffs/<CVE>/notes.md`
- [ ] Collect crash-signature snippets per bug class into
      `windows/detection/`

*Honesty note: this document describes the standard public methodology.
No original vulnerability discovery is claimed here; per-CVE diff
walk-throughs will be added as they are completed.*

---

*See [../ANALYSIS.md](../ANALYSIS.md) for the Linux-side pattern notes —
the fix-shape table above maps almost 1:1 onto the Linux classes
(UAF-after-unlock, sync/async double cleanup, unsigned underflow).*
