from __future__ import annotations

import sys
import unittest
import inspect
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from phase24_pristine_gate import (  # noqa: E402
    GateConfig,
    GateError,
    Provider,
    command_plan,
    drive_host_engine_cpu,
    observe_process_envelopes,
    pb_trace,
    parent_hardware_for_system,
    prepare_unified_backing,
    provider_for_system,
)


class Phase24PristineGateSpec(unittest.TestCase):
    def test_every_hardware_system_has_the_linux_cpu_provider(self) -> None:
        self.assertEqual(provider_for_system("Linux"), Provider.INCUS)
        self.assertEqual(provider_for_system("Darwin"), Provider.LIMA)
        self.assertEqual(provider_for_system("Windows"), Provider.WSL2)
        with self.assertRaisesRegex(GateError, "unknown-system"):
            provider_for_system("Plan9")

    def test_parent_hardware_is_distinct_from_the_linux_cpu_lane(self) -> None:
        self.assertEqual(parent_hardware_for_system("Linux", False), "linux-cpu")
        self.assertEqual(parent_hardware_for_system("Linux", True), "linux-cuda")
        self.assertEqual(parent_hardware_for_system("Darwin", True), "apple")
        self.assertEqual(parent_hardware_for_system("Windows", True), "windows")

    def test_incus_plan_is_a_vm_without_gpu_passthrough(self) -> None:
        plan = command_plan(GateConfig(provider=Provider.INCUS))
        self.assertIn("--vm", plan.create)
        self.assertIn("images:ubuntu/24.04/cloud", plan.create)
        self.assertNotIn("gpu", " ".join(plan.create).lower())
        self.assertEqual(plan.destroy[-1][-2:], ("--force", "amoebius-phase24-pristine"))

    def test_unified_backing_is_a_finite_ext4_loop_filesystem(self) -> None:
        source = inspect.getsource(prepare_unified_backing)
        self.assertIn("24G", source)
        self.assertIn("mkfs.ext4", source)
        self.assertIn("mount", source)
        self.assertIn("/var/lib/amoebius/phase24/unified", source)
        self.assertIn("{mountpoint}/kubelet", source)
        self.assertIn("{mountpoint}/containerd", source)
        self.assertIn("{mountpoint}/system/etcd", source)
        self.assertIn("{mountpoint}/system/audit", source)
        self.assertIn("{mountpoint}/system/pods", source)

    def test_process_observers_use_kernel_cgroups(self) -> None:
        readback = inspect.getsource(observe_process_envelopes)
        throttle = inspect.getsource(drive_host_engine_cpu)
        bootstrap_coordinator = inspect.getsource(pb_trace)
        self.assertIn("/sys/fs/cgroup", readback)
        self.assertIn("docker.service", readback)
        self.assertIn("containerd.service", readback)
        self.assertIn("cpu.stat", throttle)
        self.assertIn("nr_throttled", throttle)
        self.assertIn("test \"$at\" -gt \"$bt\"", throttle)
        self.assertIn("systemd-run", bootstrap_coordinator)
        self.assertIn("CPUQuota=350%", bootstrap_coordinator)
        self.assertIn("MemoryMax=7516192768", bootstrap_coordinator)
        self.assertIn("/sys/fs/cgroup", bootstrap_coordinator)

    def test_lima_plan_uses_the_ubuntu_2404_template(self) -> None:
        plan = command_plan(GateConfig(provider=Provider.LIMA))
        self.assertIn("template:ubuntu-24.04", plan.create)
        self.assertIn("--mount-none", plan.create)
        self.assertEqual(plan.guest_transport, "limactl shell + sudo -H")

    def test_wsl2_plan_requires_and_imports_a_fresh_rootfs(self) -> None:
        with self.assertRaisesRegex(GateError, "requires-rootfs"):
            command_plan(GateConfig(provider=Provider.WSL2))
        config = GateConfig(
            provider=Provider.WSL2,
            wsl_rootfs="C:/images/ubuntu-24.04.tar.gz",
            wsl_install_dir="C:/vm/amoebius-phase24-pristine",
        )
        plan = command_plan(config)
        self.assertEqual(plan.create[-2:], ("--version", "2"))
        self.assertEqual(plan.destroy[-1], ("wsl.exe", "--unregister", config.instance))


if __name__ == "__main__":
    unittest.main()
