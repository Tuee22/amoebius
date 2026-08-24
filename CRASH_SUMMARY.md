# Compiler/Linker Memory-Stall Crash — 2026-08-24

> **Purpose**: Preserve the evidence and causal assessment for the host-wide memory stall and watchdog panic
> triggered during an Amoebius compiler-component development run.
> **Nature**: Historical operational evidence, not architectural doctrine, phase status, or validation
> authority.

All times in this report are America/Toronto EDT (UTC-04:00). The affected host was a 16 GiB Apple-silicon
`MacBookPro17,1` running macOS 26.5.1 build `25F80`. The reconstruction was performed after reboot from the
kernel panic report, Codex session records, generated build artifacts, process snapshots, and host
configuration. No host or project configuration was changed during the investigation.

## Executive conclusion

The host stopped responding because it entered a global virtual-memory and paging stall, then panicked when
`watchdogd` could not check in for 90 seconds. The proximate trigger was a generated Amoebius development
harness that launched 20 compiler rows concurrently, with every successful row performing a full GHC link.

That burst ran on a 16 GiB host already carrying exceptionally large long-lived Codex and Node processes and
an active Colima VM configured for 12 GiB. At the panic, the kernel reported only about 14 MiB free, 42
swapfiles, and 100% of the compressor's segment limit in use. The process snapshot contained exactly 20
linkers, 21 GHC processes, and 20 clang processes, matching the harness's `-P 20` fan-out.

The causal finding is therefore:

> **High confidence:** Amoebius development orchestration exceeded the host's practical memory/paging
> capacity. This starved or blocked system services, including SSH and `watchdogd`, and ended in a hardware
> watchdog kernel panic at approximately 10:27:45. The diagnostic report and recovery-boot records are
> timestamped beginning at 10:28:17.

This is not evidence that compiled Amoebius application logic corrupted macOS. The failure was resource
admission and concurrency control around the development/compiler workflow.

## Impact

- The host became globally unresponsive, including to incoming SSH.
- The active compiler-component matrix did not complete.
- Twenty row directories were created beneath `.build/compiler-component-plan-driver625/`, but none reached
  its `result` artifact.
- macOS automatically rebooted after the watchdog panic.
- No tracked repository corruption was found. The Git worktree was clean before this report was added.

## Timeline

| Time | Observed event |
|---|---|
| 03:50:57 | A `ghc-9.12.4` child received `EXC_BAD_ACCESS` during a deliberate representation-invalid `unsafeCoerce` experiment. The experiment was corrected by 03:51:10 and work continued for more than six hours. This was unrelated to the host crash. |
| Approximately 10:20 | A preceding 288-row matrix using parallelism 24 completed. It contributed process and artifact churn but was not the final direct trigger. |
| 10:21:53 | A 653-row compiler-component mutation matrix launched through `xargs -n 1 -P 20 .build/compiler-component-plan-driver625/run-row.zsh`. Each successful row compiled and then performed a full GHC link. |
| 10:22:09 | Writes in the 20 created row directories stopped; none produced a final result. |
| 10:22:11 | Another GHC operation was launched from the long-running main Codex session. |
| 10:24:27 | That operation was still running after 103.1 seconds. Its Codex session record ends without completion. |
| Approximately 10:26:15 | The final 90-second interval with no `watchdogd` check-in had begun by this point. The exact first moment of global unresponsiveness is not recorded. |
| Approximately 10:27:45 | The panic's internal `Epoch Time: Calendar` records the terminal event: `watchdog timeout: no checkins from watchdogd in 90 seconds`. |
| 10:28:17 | The diagnostic report/header and early recovery-boot records begin at this timestamp; the hardware watchdog initiated the automatic reboot. |

## 1. Terminal failure mode

The panic report records:

```text
watchdog timeout: no checkins from watchdogd in 90 seconds
```

The panicked task was `kernel_task`, through `AppleARMWatchdogTimer` and the interrupt controller. The
`watchdogd` thread was turnstile-blocked on launchd, and several captured backtraces were truncated because
their pages were no longer mapped into the snapshot. That is consistent with a host unable to make reliable
forward progress under extreme VM and paging churn.

The report records no sleep or wake transition during the boot (`Sleep=0`, `Wake=0`). It contains no thermal
panic, power-loss indication, or third-party kernel extension in the panic path.
The prior boot began on 2026-06-18, so the host had been running for approximately 67 days.

This was a watchdog panic rather than a formal Jetsam/OOM kill. No 2026-08-24 Jetsam event was found, and the
panic's instantaneous `memoryPressure` flag was false. Those facts do not indicate usable headroom: the same
snapshot records the terminal state below.

| Measurement | Panic value | Interpretation |
|---|---:|---|
| Free pages | 904 × 16 KiB, approximately 14.1 MiB | Negligible immediately available memory |
| Compressor size | 453,047 pages, approximately 6.9 GiB | A very large fraction of physical memory held compressed |
| Compressed-page limit | 61%, reported `OK` | The page-count ceiling itself had not been reached |
| Compressor segment limit | 100%, reported `BAD` | The compressor could not allocate additional segments normally |
| Swapfiles | 42 | Sustained, extreme paging activity |
| Pages wanted/reclaimed | 3,096 / 487 | Immediate demand substantially exceeded reclamation |

The relevant distinction is that macOS did not select and kill one process through Jetsam. The machine instead
degraded into system-wide paging and scheduling failure until the watchdog reset it.

## 2. Workload present at the panic

The panic's process snapshot placed the dominant consumers in the same Codex/code-server resource coalition:

| Workload | Kernel-reported footprint or count |
|---|---:|
| Native `codex`, PID 4343 | Approximately 25.2 GB |
| Colima `com.apple.Virtualization.VirtualMachine`, PID 59737 | Approximately 12.9 GB |
| Nine Node processes | Approximately 11.6 GB total; PID 906 accounted for approximately 11.2 GB |
| `ld` | Exactly 20 processes, approximately 10.2 GB total |
| `ghc-9.12.4` | 21 processes, approximately 0.87 GB total |
| `clang` | 20 processes |

These figures are kernel-reported process footprints. They include shared, compressed, and/or swapped
accounting and must not be added together as literal simultaneously resident physical RAM. Their relative
magnitude and exact process counts remain strong evidence when combined with the compressor and swap state.

The baseline was already unsafe for a link-heavy burst:

- the long-lived native Codex process had accumulated an approximately 25.2 GB reported footprint;
- a Node process accounted for almost all of the approximately 11.6 GB Node total;
- Colima was configured with `cpu: 8`, `memory: 12`, and `autoActivate: true`, allowing its VM to claim three
  quarters of host physical memory while native compiler work ran beside it; and
- a parallelism-24 matrix had completed shortly before the final matrix began.

## 3. Direct correlation with the Amoebius matrix

At 10:21:53 the Codex session launched this generated command:

```text
xargs -n 1 -P 20 .build/compiler-component-plan-driver625/run-row.zsh
```

The generated driver compiled each row at line 66:

```text
ghc -c -O0 -Wall -Wextra -Werror ...
```

Every successful compilation then performed a full link beginning at line 85:

```text
ghc ...
```

The timing and cardinality line up independently:

- the controller requested 20 simultaneous rows;
- exactly 20 row directories were created before output stopped;
- the panic contained exactly 20 `ld` processes and 20 clang processes;
- it contained 21 GHC processes, accounting for the 20 rows plus other active GHC work;
- row writes stopped seconds after fan-out;
- the main session's concurrent GHC command remained incomplete; and
- no controlling session recorded successful completion before the panic.

The panic report does not contain process working directories or complete argument vectors, so it cannot name
`~/amoebius` by itself. Attribution is high confidence rather than mathematical proof because it comes from
correlating the independent panic snapshot with the timestamped Codex launch record, generated driver, exact
process count, and incomplete build artifacts.

## 4. Causal chain

The evidence supports the following sequence:

```text
67-day uptime and unusually large long-lived Codex/Node footprints
    + active Colima VM configured for 12 GiB
    + recent parallelism-24 matrix churn
    -> launch of 20 simultaneous compile/full-link rows
    -> compressor reaches 100% of its segment limit
    -> 42-swapfile paging thrash with almost no free memory
    -> launchd, watchdogd, SSH, and ordinary host work stop making progress
    -> watchdogd misses all check-ins for 90 seconds
    -> AppleARMWatchdogTimer panics the kernel
    -> automatic reboot
```

The immediate trigger was the `-P 20` full-link fan-out. The deeper root cause was that the workflow used a
fixed concurrency value without admitting its worst-case demand against physical RAM, the active VM
allocation, and existing process footprints.

## 5. Causal classification

| Question | Finding | Confidence |
|---|---|---|
| Did Amoebius development trigger the crash? | Yes. The P20 compile/full-link matrix crossed the failure threshold on an already overcommitted host. | High |
| Did Amoebius application logic corrupt macOS? | No evidence. The active subject was development/compiler orchestration, not deployed runtime logic. | High |
| Was this a formal OOM kill? | No. It was a watchdog panic during severe compressor/swap pressure. | High |
| Was the isolated 03:50 GHC crash the host crash? | No. It was a contained child failure; work continued for more than six hours. | High |
| Did sleep, power loss, or thermal shutdown cause it? | No supporting evidence; the panic identifies a watchdog reset and records no sleep/wake transition. | High |
| Did disk exhaustion cause it? | No. Approximately 564 GiB remained free at investigation time. | High |

## 6. Contributing but non-terminal conditions

- **Long process lifetime:** approximately 67 days of uptime allowed unusually large persistent development
  processes to accumulate state.
- **Colima allocation:** the VM was configured for 12 GiB and 8 CPUs on a 16 GiB host and was active during
  the native build.
- **Back-to-back high concurrency:** the final P20 matrix followed a completed P24 matrix.
- **Unbounded generated artifacts:** `.build` was approximately 136 GiB. This did not fill the disk or trigger
  the crash, but it demonstrates that the development workflow lacked a general resource-admission boundary.
- **No fail-fast host guard:** the matrix launcher did not check VM allocation, current swap/compressor state,
  other heavy processes, or link-time peak demand before spawning children.

During post-incident inspection, the attached power source reported only 15 W, which is inadequate for
sustained compiler/VM work. The incident-time wattage was not established, and there is no evidence that power
caused this panic. The first reset is explicitly recorded as a watchdog reset rather than a loss of power.

## 7. Required prevention

1. **Serialize full-link matrix rows on this host.** Use `-P 1`. Parallelism 2 should be considered only after
   a measured clean-host run establishes adequate peak-memory headroom.
2. **Give compile-only and full-link work separate limits.** Link concurrency is the critical bound and must
   not inherit a larger compile concurrency merely because both operations occur in one row driver.
3. **Stop Colima during native compiler matrices**, or reduce it from 12 GiB to approximately 2–4 GiB when it
   must coexist with them.
4. **Add a resource-admission check before fan-out.** It should refuse the run when another heavy build is
   active, Colima retains an unsafe allocation, current swap/compressor activity is elevated, or declared
   worst-case demand does not fit.
5. **Prohibit ad hoc fixed high parallelism** such as `xargs -P 20` or `-P 24` from bypassing that admission
   boundary.
6. **Rotate unusually large development sessions** before overnight stress work. A restart is not a substitute
   for admission control, but it removes the pathological accumulated baseline present in this incident.
7. **Bound and reap per-row build materializations.** `.build` needs an explicit storage ceiling and completed
   rows should discard intermediate compiler objects after retaining the required evidence.
8. **Record host pressure during long runs.** Capture process footprint, `vm_stat`, swap use, and compressor
   state periodically so an external monitor can terminate the matrix before system services stop progressing.

## 8. Preserved evidence

### 8.1 macOS diagnostic reports

| Evidence | SHA-256 |
|---|---|
| `/Library/Logs/DiagnosticReports/panic-full-2026-08-24-102817.0002.panic` | `1c5896edb8ed930b37b1ed84ad264476382d59e5eff5fc6127b79cef6524166b` |
| `/Library/Logs/DiagnosticReports/ResetCounter-2026-08-24-102820.diag` | `1215157844cbbe5b4774c96cfb522939fdb96d13a6b99a83e66ec654eed3730f` |
| `/Library/Logs/DiagnosticReports/ghc-9.12.4-2026-08-24-035111.ips` | `58c33fe5119a59f063347adc4fdf991a2a68cbfaead6e4c71f9b890ca12296ab` |

The panic report's incident/boot-session UUID is `FB017759-D08F-4750-ACBE-95BB5E7079CE`.

### 8.2 Development-session correlation

- P20 matrix launch:
  `/Users/matt/.codex/sessions/2026/08/24/rollout-2026-08-24T01-09-00-01a0322c-0314-7980-89ed-80ddfc215d0a.jsonl`,
  line 11062.
- Concurrent main-session GHC launch and final incomplete status:
  `/Users/matt/.codex/sessions/2026/08/21/rollout-2026-08-21T07-45-04-01a02423-8b69-7e72-977d-b90215e59eb5.jsonl`,
  lines 75814–75815.
- Generated row driver:
  `/Users/matt/amoebius/.build/compiler-component-plan-driver625/run-row.zsh`, compile at line 66 and link at
  line 85.
- Colima allocation:
  `/Users/matt/.colima/default/colima.yaml`, CPU at line 3, memory at line 13, and auto-activation at line 67.

The `.codex` session files are mutable operational evidence and may rotate. The hashed diagnostic reports and
this report preserve the core reconstruction, but copying the source reports to retained storage would provide
stronger long-term evidence continuity.

## 9. Residual uncertainty

The available evidence does not establish the exact second at which host responsiveness was first lost, and
the panic report by itself does not identify `~/amoebius` as the working directory. Those limits do not alter
the primary finding: the independently timestamped P20 compiler/linker fan-out matches the exact process burst
captured at the terminal compressor/swap state immediately before the watchdog panic.
