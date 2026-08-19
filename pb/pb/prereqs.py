"""The per-substrate floor, and the one acquisition `pb` performs before the binary.

The floor is what must already be true before `pb` can do anything at all. Only
three classes belong to it — the **package-manager root**, because it cannot be
installed through a resolved tool; a **hardware or firmware fact**, because
software cannot enable it; and a **credentialed account**, because it is not
amoebius's to create. Everything else with a supported install plan is *ensured*
([`substrate_doctrine.md` section 3.1](../../documents/engineering/substrate_doctrine.md)).

Two properties of that doctrine are load-bearing here and are why this module is
mostly data:

* **The tables are authored data, not a description of one.** A row carries the
  prerequisite id, what needs it, the probe that decides it, and the remedy that
  clears it. Prose describing a check that some function separately implements is
  how the two come to disagree.
* **A refusal is a value, not a crash**, and the whole floor is decidable for a
  substrate the running host is not. That is what lets an apple host check that
  the plan for windows is still well-formed, and it is checked on every run
  rather than only on the substrate that would execute it.

The floor is evaluated *before* any requirement is resolved, so a host that cannot
support the run is told which prerequisite is missing and what clears it, instead
of being walked several requirements deep into a symptom.
"""

from __future__ import annotations

import dataclasses
import enum
import hashlib
import json
import os
import platform
import shutil
import stat
import tempfile
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path

from pb import bootstrap_toolchain as toolchain
from pb import narrow, process
from pb.process import Kind, Ledger


class PrerequisiteError(RuntimeError):
    """The floor could not be decided — an input failure, not a refusal."""


class Substrate(enum.Enum):
    """The closed substrate catalogue. A fifth member is a doctrine change."""

    APPLE = "apple"
    LINUX_CPU = "linux-cpu"
    LINUX_CUDA = "linux-cuda"
    WINDOWS = "windows"

    def __str__(self) -> str:
        return self.value


# --------------------------------------------------------------------------
# probes — a closed sum, so a new probe shape cannot be added by accident
# --------------------------------------------------------------------------


class ProbeKind(enum.Enum):
    EXECUTABLE = "executable"
    COMMAND = "command"
    WRITABLE_DEVICE = "writable-device"
    ARCHITECTURE = "architecture"
    FIRMWARE_FLAG = "firmware-flag"

    def __str__(self) -> str:
        return self.value


@dataclasses.dataclass(frozen=True)
class Probe:
    """How one prerequisite is decided, as data.

    `subject` is the absolute path, architecture token, or firmware flag name the
    probe reads; `arguments` is the argv a `COMMAND` probe issues. Every probe that
    starts a child does so through `pb.process`, by absolute path.
    """

    kind: ProbeKind
    subject: str
    arguments: tuple[str, ...] = ()

    def render(self) -> str:
        return f"{self.kind}:{self.subject}" + (
            f" {' '.join(self.arguments)}" if self.arguments else ""
        )


@dataclasses.dataclass(frozen=True)
class Prerequisite:
    """One authored floor row."""

    identifier: str
    required_for: str
    probe: Probe
    remedy: str
    # `linux-cuda.accelerator` is deliberately not a refusal: a host without the
    # driver classifies as `linux-cpu`, so the lane is never offered rather than
    # the run being refused.
    refuses: bool = True


@dataclasses.dataclass(frozen=True)
class Refusal:
    """A floor row that did not hold, carrying what clears it."""

    substrate: Substrate
    identifier: str
    remedy: str

    def render(self) -> str:
        return (
            f"pb: {self.substrate}: {self.identifier} is not satisfied\n     remedy: {self.remedy}"
        )


# --------------------------------------------------------------------------
# the authored floor
# --------------------------------------------------------------------------

_LINUX_ROWS: tuple[Prerequisite, ...] = (
    Prerequisite(
        "linux.package-manager-root",
        "the C libraries the compiler links, and the container engine",
        Probe(ProbeKind.EXECUTABLE, "/usr/bin/apt-get"),
        "install the system package manager; amoebius cannot install the root it installs through",
    ),
    Prerequisite(
        "linux.privilege",
        "package installation and provider initialisation",
        Probe(ProbeKind.COMMAND, "/usr/bin/sudo", ("-n", "true")),
        "grant passwordless sudo to the invoking user, so the probe does not prompt",
    ),
    Prerequisite(
        "linux.virtualization",
        "the pristine-guest provider",
        Probe(ProbeKind.WRITABLE_DEVICE, "/dev/kvm"),
        "enable virtualization in firmware, load the kvm module, and make /dev/kvm writable by the invoking user",
    ),
)

FLOOR: Mapping[Substrate, tuple[Prerequisite, ...]] = {
    Substrate.APPLE: (
        Prerequisite(
            "apple.package-manager-root",
            "every ensured tool, and Lima",
            Probe(ProbeKind.EXECUTABLE, "/opt/homebrew/bin/brew"),
            "install Homebrew from https://brew.sh; it is verified, never installed by pb",
        ),
        Prerequisite(
            "apple.command-line-tools",
            "the fixed Metal bridge, and every on-host source build",
            Probe(ProbeKind.COMMAND, "/usr/bin/xcode-select", ("-p",)),
            "run xcode-select --install; full Xcode remains deliberately excluded",
        ),
        Prerequisite(
            "apple.silicon",
            "the substrate itself",
            Probe(ProbeKind.ARCHITECTURE, "arm64"),
            "run on Apple Silicon; detection refuses macOS on any other architecture",
        ),
    ),
    Substrate.LINUX_CPU: _LINUX_ROWS,
    Substrate.LINUX_CUDA: (
        *_LINUX_ROWS,
        Prerequisite(
            "linux-cuda.accelerator",
            "the CUDA lane only",
            Probe(ProbeKind.EXECUTABLE, "/usr/bin/nvidia-smi"),
            "install the NVIDIA kernel driver; without it the host simply classifies as linux-cpu",
            refuses=False,
        ),
    ),
    Substrate.WINDOWS: (
        Prerequisite(
            "windows.package-manager-root",
            "every ensured tool",
            Probe(ProbeKind.EXECUTABLE, "C:/Windows/System32/winget.exe"),
            "install App Installer from the Microsoft Store, which supplies winget",
        ),
        Prerequisite(
            "windows.shell",
            "the pre-binary bootstrap and every host-boundary invocation",
            Probe(
                ProbeKind.EXECUTABLE,
                "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
            ),
            "repair the Windows installation; PowerShell ships with the operating system",
        ),
        Prerequisite(
            "windows.firmware-virtualization",
            "WSL2, and therefore the whole Linux lane",
            Probe(ProbeKind.FIRMWARE_FLAG, "VirtualizationFirmwareEnabled"),
            "enable virtualization in BIOS/UEFI; no software can enable it",
        ),
        Prerequisite(
            "windows.elevation",
            "the WSL2 feature install and the hypervisor launch setting",
            Probe(ProbeKind.FIRMWARE_FLAG, "IsAdministrator"),
            "re-run pb from an Administrator shell",
        ),
        Prerequisite(
            "windows.reboot",
            "completing a WSL2 or hypervisor change",
            Probe(ProbeKind.FIRMWARE_FLAG, "NoRebootPending"),
            "reboot and retry; a pending reboot is a first-class outcome, never a silent hang",
        ),
    ),
}


# --------------------------------------------------------------------------
# decidability — checked on every run, for every substrate
# --------------------------------------------------------------------------


def well_formed() -> tuple[str, ...]:
    """Every problem with the floor *as a plan*, for every substrate.

    This is the half that is decidable on a host the substrate is not. It is run on
    every run, so a plan that has stopped being well-formed for windows fails on an
    apple host that will never execute it.
    """
    problems: list[str] = []
    # An id may be declared by more than one substrate -- `linux-cuda`'s floor is
    # `linux-cpu`'s plus the accelerator row, and sharing the rows is what makes that
    # true rather than merely similar. The defect is the same id carrying *different*
    # content on two substrates, which is a fork nothing reads.
    seen: dict[str, Prerequisite] = {}
    for substrate in Substrate:
        rows = FLOOR.get(substrate, ())
        if not rows:
            problems.append(f"{substrate}: the catalogue member declares no floor")
            continue
        for row in rows:
            if not row.identifier:
                problems.append(f"{substrate}: a row carries no prerequisite id")
            if not row.required_for:
                problems.append(f"{row.identifier}: the row does not say what needs it")
            if not row.remedy:
                problems.append(f"{row.identifier}: the row carries no remedy")
            if row.probe.kind is ProbeKind.COMMAND and not row.probe.arguments:
                problems.append(f"{row.identifier}: a command probe issues no argv")
            if row.probe.kind in {ProbeKind.EXECUTABLE, ProbeKind.COMMAND}:
                subject = row.probe.subject
                absolute = subject.startswith("/") or (len(subject) > 2 and subject[1] == ":")
                if not absolute:
                    problems.append(
                        f"{row.identifier}: the probe names {subject!r}, which is not an absolute path"
                    )
            declared = seen.get(row.identifier)
            if declared is not None and declared != row:
                problems.append(
                    f"{row.identifier}: two substrates declare it with different content"
                )
            seen[row.identifier] = row
    return tuple(problems)


def evaluate(substrate: Substrate, facts: Mapping[str, bool]) -> tuple[Refusal, ...]:
    """The refusals this floor yields, given what was observed.

    A row whose fact is absent from `facts` is *not* silently satisfied: an
    unobserved prerequisite is treated as unmet, because a floor that passes for
    want of an observation is exactly the floor that lets a run start on a host it
    cannot finish on.
    """
    refusals: list[Refusal] = []
    for row in FLOOR.get(substrate, ()):
        if not row.refuses:
            continue
        if not facts.get(row.identifier, False):
            refusals.append(Refusal(substrate, row.identifier, row.remedy))
    return tuple(refusals)


# --------------------------------------------------------------------------
# observation — the probes, run against the host this actually is
# --------------------------------------------------------------------------


def observe_probe(probe: Probe, *, ledger: Ledger | None = None) -> bool:
    """Decide one probe on this host. Every branch is total over `ProbeKind`."""
    if probe.kind is ProbeKind.EXECUTABLE:
        return process.executable_problem(Path(probe.subject)) is None
    if probe.kind is ProbeKind.COMMAND:
        executable = Path(probe.subject)
        if process.executable_problem(executable) is not None:
            return False
        completed = process.run(
            executable, probe.arguments, kind=Kind.PROBE, ledger=ledger, mirror=False
        )
        return completed.ok
    if probe.kind is ProbeKind.WRITABLE_DEVICE:
        node = Path(probe.subject)
        return node.exists() and os.access(node, os.W_OK)
    if probe.kind is ProbeKind.ARCHITECTURE:
        return platform.machine().lower() in _ARCHITECTURE_ALIASES.get(probe.subject, set())
    # FIRMWARE_FLAG. Reading it needs the substrate's own shell, which exists only
    # on that substrate; on any other host the flag is unobservable and the row is
    # therefore unmet rather than assumed.
    return False


_ARCHITECTURE_ALIASES: Mapping[str, set[str]] = {
    "arm64": {"arm64", "aarch64"},
    "amd64": {"amd64", "x86_64"},
}


def observe(substrate: Substrate, *, ledger: Ledger | None = None) -> dict[str, bool]:
    """Observe every row of one substrate's floor, in table order."""
    return {
        row.identifier: observe_probe(row.probe, ledger=ledger) for row in FLOOR.get(substrate, ())
    }


def detect() -> Substrate:
    """Classify this host. macOS on anything but Apple Silicon is refused outright."""
    system = platform.system().lower()
    if system == "darwin":
        if platform.machine().lower() not in _ARCHITECTURE_ALIASES["arm64"]:
            raise PrerequisiteError("apple-substrate-requires-apple-silicon")
        return Substrate.APPLE
    if system == "windows":
        return Substrate.WINDOWS
    if system == "linux":
        if process.executable_problem(Path("/usr/bin/nvidia-smi")) is None:
            return Substrate.LINUX_CUDA
        return Substrate.LINUX_CPU
    raise PrerequisiteError(f"unsupported-host-system:{system}")


def assert_floor(substrate: Substrate, *, ledger: Ledger | None = None) -> tuple[Refusal, ...]:
    """The whole floor assertion: the plan, then this host's rows.

    The plan half runs first and for every substrate, because a malformed plan is a
    defect in amoebius rather than a fact about the operator's machine, and telling
    an operator to fix their BIOS because a table lost its remedy column would be
    the wrong answer to the right observation.
    """
    problems = well_formed()
    if problems:
        raise PrerequisiteError("floor-plan-malformed:" + "; ".join(problems))
    return evaluate(substrate, observe(substrate, ledger=ledger))


# --------------------------------------------------------------------------
# the one acquisition pb performs
# --------------------------------------------------------------------------


def download_verified(url: str, expected_sha256: str, target: Path) -> str:
    """Fetch an asset and refuse anything the publisher does not vouch for.

    No installer is piped to a shell. The digest compared against is the
    publisher's own, fetched by the resolver in this same run, so it is a
    corruption check for this download rather than a permanent pin -- and the
    observed value is returned so the run records what it actually got.
    """
    if not url.startswith("https://"):
        raise PrerequisiteError(f"refusing a non-https publisher URL: {url}")
    target.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with tempfile.NamedTemporaryFile(
        prefix=target.name + ".", dir=target.parent, delete=False
    ) as handle:
        temporary = Path(handle.name)
        try:
            with urllib.request.urlopen(url, timeout=120) as response:  # noqa: S310
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    handle.write(block)
                    digest.update(block)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    observed = digest.hexdigest()
    if observed != expected_sha256:
        temporary.unlink(missing_ok=True)
        raise PrerequisiteError(f"download-digest-mismatch:{target.name}")
    temporary.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IXGRP)
    os.replace(temporary, target)
    return observed


def render(refusals: Sequence[Refusal]) -> str:
    """Every refusal, one per stanza, each naming what clears it."""
    return "\n".join(refusal.render() for refusal in refusals)


# --------------------------------------------------------------------------
# capacity admission — the other half of "before any requirement is resolved"
# --------------------------------------------------------------------------
#
# The floor above asks whether the host *can* supply what only it can supply.
# This asks whether it has room to do the work, and refuses before the first
# mutation rather than partway through one. Both readings are injected rather
# than hard-wired to `/proc`, so every arm is decidable on a host that is not the
# one the envelope describes -- the same decidability the floor has.


@dataclasses.dataclass(frozen=True)
class HostObservation:
    """What the host reported, once, at one instant."""

    cpu_count: int
    memory_available_bytes: int
    disk_available_bytes: int
    fingerprint: str


@dataclasses.dataclass
class ValidatedExecution:
    """Permission to perform exactly one mutation, on exactly one host.

    It is one-shot on purpose. A token that could be spent twice would let a
    second mutation run on an admission the first already consumed, and a token
    that did not re-check the fingerprint would let it run on a host that changed
    underneath it.
    """

    fingerprint: str
    consumed: bool = False

    def consume(self, current: HostObservation) -> None:
        if self.consumed:
            raise PrerequisiteError("validated-execution-already-consumed")
        if current.fingerprint != self.fingerprint:
            raise PrerequisiteError("host-fingerprint-changed")
        self.consumed = True


AUTHORED_ENVELOPE_KEYS = frozenset({"schema", "_comment", "installer", "build"})
EXPECTED_STEP_TOOLS = ("ghcup", "ghc", "cabal", "kubectl", "kind")


def assert_authored_envelope(envelope: Mapping[str, object]) -> None:
    """Refuse an envelope that has started carrying resolver output.

    A resolved version, URL, or digest appearing here would be run-local
    observation in a tracked file. The check is the point of the split: this file
    cannot come to pin a tool again without the refusal firing.
    """
    installer = narrow.as_mapping(envelope.get("installer"), "installer")
    steps = narrow.as_sequence(installer.get("steps"), "installer.steps")
    tools = tuple(str(narrow.as_mapping(step, "installer.step").get("tool", "")) for step in steps)
    if tools != EXPECTED_STEP_TOOLS or len(tools) != len(set(tools)):
        raise PrerequisiteError("install-plan-envelope-exact-join-failed")
    if set(envelope) - AUTHORED_ENVELOPE_KEYS:
        raise PrerequisiteError("envelope-carries-resolver-output")


def required_disk(envelope: Mapping[str, object], stage: str) -> int:
    """The peak the stage actually reaches, not the sum of its parts.

    An installer's steps land one after another, so the peak is the largest
    running total plus that step's own workspace -- never the sum of every
    workspace at once, which would refuse hosts that can in fact do the work.
    """
    demand = narrow.as_mapping(envelope.get(stage), stage)
    if stage != "installer":
        return narrow.as_int(demand.get("scratch_bytes"), f"{stage}.scratch_bytes") + narrow.as_int(
            demand.get("cache_write_bytes"), f"{stage}.cache_write_bytes"
        )
    steps = [
        narrow.as_mapping(step, "installer.step")
        for step in narrow.as_sequence(demand.get("steps"), "installer.steps")
    ]
    peak = max(
        sum(
            narrow.as_int(prior.get("installed_bytes"), "installed_bytes")
            for prior in steps[:index]
        )
        + narrow.as_int(step.get("installed_bytes"), "installed_bytes")
        + narrow.as_int(step.get("workspace_bytes"), "workspace_bytes")
        for index, step in enumerate(steps)
    )
    return max(
        narrow.as_int(demand.get("tool_install_backing_bytes"), "tool_install_backing_bytes"),
        peak,
    )


def validate_envelope(
    envelope: Mapping[str, object], observation: HostObservation, stage: str
) -> ValidatedExecution:
    """Admit one stage against one observation, or refuse naming the axis."""
    demand = narrow.as_mapping(envelope.get(stage), stage)
    if observation.cpu_count < narrow.as_int(demand.get("cpu_count"), f"{stage}.cpu_count"):
        raise PrerequisiteError(f"{stage}-cpu-overdraw")
    if observation.memory_available_bytes < narrow.as_int(
        demand.get("memory_bytes"), f"{stage}.memory_bytes"
    ):
        raise PrerequisiteError(f"{stage}-memory-overdraw")
    if observation.disk_available_bytes < required_disk(envelope, stage):
        raise PrerequisiteError(f"{stage}-disk-overdraw")
    return ValidatedExecution(observation.fingerprint)


# --------------------------------------------------------------------------
# ensuring the Haskell toolchain
# --------------------------------------------------------------------------
#
# The four-step ensure contract of `substrate_doctrine.md` section 3: probe, install
# if absent, resolve the absolute path from the provider, invoke by that path. The
# probe is also the post-condition, which is the property that makes a converged
# re-run report converged rather than claim it -- an assertion that verified some
# other predicate would report a convergence it never reached.
#
# The collaborators are injected rather than reached for. Resolution touches the
# network and installation touches the host, so a suite that could not substitute
# them could only be run on a host willing to be mutated, and the refusal arms --
# the ones that matter -- would never execute at all.

TOOLCHAIN = ("ghcup", "ghc", "cabal", "kubectl", "kind")


@dataclasses.dataclass(frozen=True)
class Toolchain:
    """Every tool `pb` needs, each as the absolute path it was resolved to."""

    ghcup: Path
    ghc: Path
    cabal: Path
    kubectl: Path
    kind: Path

    def render(self) -> str:
        return "".join(
            f"{name}\t{path}\n" for name, path in sorted(dataclasses.asdict(self).items())
        )


def candidate_paths(home: Path) -> dict[str, tuple[Path, ...]]:
    """Where each tool lands, by name only.

    No candidate carries a version. `ghcup install ... --set` maintains the
    unversioned name, so the path is a fact about the layout while *which* version
    sits behind it is a run-local resolution -- checked against the authored
    requirement rather than encoded in a filename that quietly stops matching.
    """
    return {
        "ghcup": (home / ".ghcup/bin/ghcup", Path("/usr/local/bin/ghcup")),
        "ghc": (home / ".ghcup/bin/ghc",),
        "cabal": (home / ".ghcup/bin/cabal",),
        "kubectl": (
            home / ".local/bin/kubectl",
            Path("/usr/local/bin/kubectl"),
            Path("/usr/bin/kubectl"),
        ),
        "kind": (home / ".local/bin/kind", Path("/usr/local/bin/kind")),
    }


def install_target(home: Path, name: str) -> Path:
    """Where `pb` lays a tool down -- always beneath the run-local home.

    Discovery and installation are different questions with different answers. A
    tool the operator already has may live in `/usr/local/bin`, and finding it there
    is fine; *writing* there would need privilege `pb` does not ask for and would
    leave amoebius-owned state outside the checkout, which section S clause 12
    refuses. So every candidate list opens with the home-local path, and that first
    entry -- and only it -- is an install target.
    """
    target = candidate_paths(home)[name][0]
    if not target.is_relative_to(home):
        raise PrerequisiteError(f"install-target-outside-the-run-home:{target}")
    return target


def first_executable(paths: Sequence[Path]) -> Path | None:
    """The first candidate that is an absolute, executable file."""
    for path in paths:
        if path.is_absolute() and process.executable_problem(path) is None:
            return path
    return None


def preflight(home: Path) -> dict[str, bool]:
    """Which tools are present, before anything is done about the ones that are not."""
    candidates = candidate_paths(home)
    return {name: first_executable(candidates[name]) is not None for name in TOOLCHAIN}


def render_preflight(state: Mapping[str, bool]) -> str:
    return "".join(f"{name}\t{'present' if state[name] else 'absent'}\n" for name in sorted(state))


VM_STAT = Path("/usr/bin/vm_stat")
# Darwin's `vm_stat` reports pages by class. Free, inactive and speculative are the
# three the kernel will hand to a new allocation without swapping; wired and active
# are not, so summing all five would report memory the run cannot actually have.
DARWIN_AVAILABLE_CLASSES = ("Pages free", "Pages inactive", "Pages speculative")


def available_memory(page: int) -> int:
    """Memory a new allocation can have, asked of whichever kernel is answering.

    `SC_AVPHYS_PAGES` is the portable spelling and Linux answers it. Darwin does not
    define it at all -- it is absent from `os.sysconf_names` -- so the reading falls
    through to `vm_stat`, at its absolute path like every other tool. Falling back to
    *total* memory instead would silently turn an admission into a rubber stamp.
    """
    if "SC_AVPHYS_PAGES" in os.sysconf_names:
        return os.sysconf("SC_AVPHYS_PAGES") * page
    if process.executable_problem(VM_STAT) is not None:
        raise PrerequisiteError("memory-observation-unavailable")
    completed = process.run(VM_STAT, [], kind=Kind.PROBE, mirror=False)
    if not completed.ok:
        raise PrerequisiteError("memory-observation-unavailable")
    total = 0
    for line in completed.output.splitlines():
        label, separator, count = line.partition(":")
        if separator and label.strip() in DARWIN_AVAILABLE_CLASSES:
            total += int(count.strip().rstrip("."))
    return total * page


def observe_host(path: Path) -> HostObservation:
    """What this host can currently spare, read portably.

    The predecessor read `/proc/meminfo` and `/proc/self/cgroup` directly, which
    made the whole admission Linux-only and therefore undecidable on two of the
    four catalogue members. `sysconf` answers the same question on every POSIX
    substrate, so the admission is now decidable wherever the floor is.
    """
    usage = shutil.disk_usage(path)
    page = os.sysconf("SC_PAGE_SIZE")
    available = available_memory(page)
    inputs = {
        "machine": platform.machine(),
        "system": platform.system(),
        "cpu_count": os.cpu_count() or 0,
        "memory_total": os.sysconf("SC_PHYS_PAGES") * page,
        "disk_device": os.stat(path).st_dev,
        "disk_total": usage.total,
    }
    encoded = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()
    return HostObservation(
        cpu_count=os.cpu_count() or 0,
        memory_available_bytes=available,
        disk_available_bytes=usage.free,
        fingerprint=hashlib.sha256(encoded).hexdigest(),
    )


@dataclasses.dataclass(frozen=True)
class Acquisition:
    """The collaborators an ensure run uses, so a suite can supply its own.

    Each default is the real thing. Naming them here rather than reaching for them
    inside the driver is what lets the absent -> present -> present replay run
    against a committed fake host instead of against a machine.
    """

    resolve_acquired: Callable[[Path], Mapping[str, toolchain.Resolved]] = (
        toolchain.resolve_acquired
    )
    resolve_managed: Callable[[Path, Path, Path], Mapping[str, toolchain.Resolved]] = (
        toolchain.resolve_ghcup_managed
    )
    download: Callable[[str, str, Path], str] = download_verified
    observe: Callable[[Path], HostObservation] = observe_host


def _admit(
    envelope: Mapping[str, object], root: Path, stage: str, acquisition: Acquisition
) -> None:
    """Admit one mutation, then spend the admission on a re-observation.

    Observing twice is the point: the token is minted against the first reading
    and consumed against the second, so a host that changed between the decision
    and the act refuses rather than proceeding on a stale answer.
    """
    token = validate_envelope(envelope, acquisition.observe(root), stage)
    token.consume(acquisition.observe(root))


def ensure_toolchain(
    *,
    root: Path,
    home: Path,
    envelope: Mapping[str, object],
    ledger: Ledger | None = None,
    acquisition: Acquisition | None = None,
) -> Toolchain:
    """Probe, install what is absent, resolve every path, and verify the probe again.

    Resolution reaches the network, so it happens only when something is actually
    missing: a converged re-run installs nothing and therefore resolves nothing,
    which is what keeps the second pass free of both mutations and observations.
    """
    plan = acquisition or Acquisition()
    candidates = candidate_paths(home)
    acquired: dict[str, toolchain.Resolved] = {}
    observations: dict[str, toolchain.Resolved] = {}

    def resolved(name: str) -> toolchain.Resolved:
        if not acquired:
            acquired.update(plan.resolve_acquired(root))
        return acquired[name]

    ghcup = first_executable(candidates["ghcup"])
    if ghcup is None:
        record = resolved("ghcup")
        ghcup = install_target(home, "ghcup")
        _admit(envelope, root, "installer", plan)
        plan.download(record.url, record.publisher_sha256, ghcup)
        if ledger is not None:
            ledger.note(Kind.MUTATION, "acquire", "ghcup", str(ghcup))
        observations["ghcup"] = record

    managed: dict[str, toolchain.Resolved] = {}
    for name in ("ghc", "cabal"):
        if first_executable(candidates[name]) is not None:
            continue
        if not managed:
            managed.update(plan.resolve_managed(root, ghcup, home))
        _admit(envelope, root, "installer", plan)
        process.run_checked(
            ghcup,
            ["install", name, managed[name].version, "--set"],
            kind=Kind.MUTATION,
            ledger=ledger,
            overlay={"HOME": str(home)},
        )
        observations[name] = managed[name]

    for name in ("kubectl", "kind"):
        if first_executable(candidates[name]) is not None:
            continue
        record = resolved(name)
        target = install_target(home, name)
        _admit(envelope, root, "installer", plan)
        plan.download(record.url, record.publisher_sha256, target)
        if ledger is not None:
            ledger.note(Kind.MUTATION, "acquire", name, str(target))
        observations[name] = record

    # The probe is the post-condition. Re-running it -- rather than trusting that
    # the install returned zero -- is what makes "converged" an observation.
    final: dict[str, Path | None] = {}
    for name in TOOLCHAIN:
        found = first_executable(candidates[name])
        final[name] = found
        if ledger is not None:
            ledger.note(Kind.PROBE, "post-condition", name, "present" if found else "absent")
    missing = sorted(name for name, path in final.items() if path is None)
    if missing:
        raise PrerequisiteError("tool-install-did-not-converge:" + ",".join(missing))
    if observations:
        toolchain.store(root, observations)
    return Toolchain(
        ghcup=_present(final["ghcup"]),
        ghc=_present(final["ghc"]),
        cabal=_present(final["cabal"]),
        kubectl=_present(final["kubectl"]),
        kind=_present(final["kind"]),
    )


def _present(path: Path | None) -> Path:
    """Narrow a probe result the convergence check has already established."""
    if path is None:  # pragma: no cover - the convergence check raised first
        raise PrerequisiteError("tool-resolved-to-nothing")
    return path
