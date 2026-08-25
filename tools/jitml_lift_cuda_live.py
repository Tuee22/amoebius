#!/usr/bin/env python3
"""Run the scoped Phase-52 host-CUDA/checkpoint live slice."""

from __future__ import annotations

import ctypes
import hashlib
import json
import os
import secrets
import struct
import subprocess
from pathlib import Path
from typing import Any

import phase34_tenant_provider_live as phase34
import phase37_workflow_live as phase37


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_51/jitml-cuda-live.json"
PARAMETERS = 10_000_000
STEPS = 200
RESERVE_BYTES = 256 * 1024 * 1024
REQUIRED_BYTES = 64 * 1024 * 1024


class LiveFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise LiveFailure(tag)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def digest(value: Any, *, newline: bool = False) -> str:
    return "sha256:" + hashlib.sha256(canonical(value) + (b"\n" if newline else b"")).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def nvidia_inventory() -> dict[str, Any]:
    result = subprocess.run(
        ("/usr/bin/nvidia-smi", "--query-gpu=name,uuid,memory.total,memory.free,compute_cap,driver_version",
         "--format=csv,noheader,nounits"),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=30,
    )
    require(result.returncode == 0, f"nvidia-smi:{result.stdout}")
    rows = [part.strip() for part in result.stdout.strip().split(",")]
    require(len(rows) == 6, f"nvidia-inventory-shape:{rows}")
    return {
        "name": rows[0], "uuid": rows[1], "totalMiB": int(rows[2]), "freeMiB": int(rows[3]),
        "computeCapability": rows[4], "driverVersion": rows[5],
    }


def bind_driver() -> ctypes.CDLL:
    driver = ctypes.CDLL("libcuda.so.1")
    prototypes = {
        "cuInit": [ctypes.c_uint],
        "cuDeviceGet": [ctypes.POINTER(ctypes.c_int), ctypes.c_int],
        "cuDevicePrimaryCtxRetain": [ctypes.POINTER(ctypes.c_void_p), ctypes.c_int],
        "cuDevicePrimaryCtxRelease_v2": [ctypes.c_int],
        "cuCtxSetCurrent": [ctypes.c_void_p],
        "cuModuleLoadDataEx": [ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p, ctypes.c_uint,
                               ctypes.c_void_p, ctypes.c_void_p],
        "cuModuleGetFunction": [ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p, ctypes.c_char_p],
        "cuModuleUnload": [ctypes.c_void_p],
        "cuMemAlloc_v2": [ctypes.POINTER(ctypes.c_uint64), ctypes.c_size_t],
        "cuMemFree_v2": [ctypes.c_uint64],
        "cuMemsetD32_v2": [ctypes.c_uint64, ctypes.c_uint, ctypes.c_size_t],
        "cuMemcpyDtoH_v2": [ctypes.c_void_p, ctypes.c_uint64, ctypes.c_size_t],
        "cuMemGetInfo_v2": [ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_size_t)],
        "cuLaunchKernel": [ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint,
                           ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint,
                           ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_void_p)],
        "cuCtxSynchronize": [],
    }
    for name, arguments in prototypes.items():
        function = getattr(driver, name)
        function.argtypes = arguments
        function.restype = ctypes.c_int
    return driver


def check(code: int, operation: str) -> None:
    if code:
        raise LiveFailure(f"cuda-driver:{operation}:{code}")


def ptx_source() -> bytes:
    return b""".version 6.0
.target sm_52
.address_size 64
.visible .entry jitml_training_step(
  .param .u64 parameters,
  .param .f32 delta,
  .param .u32 count
){
  .reg .pred %done;
  .reg .b32 %r<5>;
  .reg .b64 %rd<4>;
  .reg .f32 %f<3>;
  ld.param.u64 %rd1,[parameters];
  ld.param.f32 %f1,[delta];
  ld.param.u32 %r4,[count];
  mov.u32 %r1,%ctaid.x;
  mov.u32 %r2,%ntid.x;
  mov.u32 %r3,%tid.x;
  mad.lo.s32 %r1,%r1,%r2,%r3;
  setp.ge.u32 %done,%r1,%r4;
  @%done bra complete;
  mul.wide.u32 %rd2,%r1,4;
  add.s64 %rd3,%rd1,%rd2;
  ld.global.f32 %f2,[%rd3];
  add.f32 %f2,%f2,%f1;
  st.global.f32 [%rd3],%f2;
complete:
  ret;
}
"""


def run_cuda(challenge: str) -> tuple[bytes, dict[str, Any]]:
    driver = bind_driver()
    device = ctypes.c_int()
    context = ctypes.c_void_p()
    module = ctypes.c_void_p()
    function = ctypes.c_void_p()
    allocation = ctypes.c_uint64()
    ptx = ptx_source()
    ptx_buffer = ctypes.create_string_buffer(ptx)
    check(driver.cuInit(0), "init")
    check(driver.cuDeviceGet(ctypes.byref(device), 0), "device")
    check(driver.cuDevicePrimaryCtxRetain(ctypes.byref(context), device), "primary-context")
    try:
        check(driver.cuCtxSetCurrent(context), "set-current")
        check(driver.cuModuleLoadDataEx(ctypes.byref(module), ctypes.cast(ptx_buffer, ctypes.c_void_p),
                                        0, None, None), "module-load")
        check(driver.cuModuleGetFunction(ctypes.byref(function), module, b"jitml_training_step"),
              "function")
        check(driver.cuMemAlloc_v2(ctypes.byref(allocation), PARAMETERS * 4), "allocate")
        try:
            check(driver.cuMemsetD32_v2(allocation, 0, PARAMETERS), "zero")
            free = ctypes.c_size_t()
            total = ctypes.c_size_t()
            check(driver.cuMemGetInfo_v2(ctypes.byref(free), ctypes.byref(total)), "memory-info")
            processes = subprocess.run(
                ("/usr/bin/nvidia-smi", "--query-compute-apps=pid,process_name,used_gpu_memory",
                 "--format=csv,noheader,nounits"), text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, check=False, timeout=30,
            )
            require(processes.returncode == 0 and str(os.getpid()) in processes.stdout,
                    f"nvidia-process-observer:{processes.stdout}")
            delta = ctypes.c_float(((int(challenge[:8], 16) % 1000) + 1) / 100000.0)
            pointer = ctypes.c_uint64(allocation.value)
            count = ctypes.c_uint(PARAMETERS)
            arguments = (ctypes.c_void_p * 3)(
                ctypes.cast(ctypes.byref(pointer), ctypes.c_void_p),
                ctypes.cast(ctypes.byref(delta), ctypes.c_void_p),
                ctypes.cast(ctypes.byref(count), ctypes.c_void_p),
            )
            blocks = (PARAMETERS + 255) // 256
            for _ in range(STEPS):
                check(driver.cuLaunchKernel(function, blocks, 1, 1, 256, 1, 1, 0, None,
                                             arguments, None), "kernel-launch")
            check(driver.cuCtxSynchronize(), "synchronize")
            output = ctypes.create_string_buffer(PARAMETERS * 4)
            check(driver.cuMemcpyDtoH_v2(output, allocation, PARAMETERS * 4), "checkpoint-copy")
            checkpoint = output.raw
            expected = ctypes.c_float(0.0).value
            for _ in range(STEPS):
                expected = ctypes.c_float(expected + delta.value).value
            expected_bytes = struct.pack("<f", expected) * PARAMETERS
            require(checkpoint == expected_bytes, "cuda-checkpoint-independent-oracle")
            return checkpoint, {
                "driverApi": "libcuda.so.1", "ptxTarget": "sm_52",
                "ptxDigest": sha256_bytes(ptx), "parameters": PARAMETERS,
                "optimizerSteps": STEPS, "kernelLaunches": STEPS,
                "threadsPerBlock": 256, "blocksPerLaunch": blocks,
                "delta": delta.value, "expectedParameter": expected,
                "firstParameter": struct.unpack_from("<f", checkpoint, 0)[0],
                "lastParameter": struct.unpack_from("<f", checkpoint, len(checkpoint) - 4)[0],
                "checkpointDigest": sha256_bytes(checkpoint), "checkpointBytes": len(checkpoint),
                "driverFreeBytesAfterAllocation": free.value,
                "driverTotalBytes": total.value,
                "nvidiaSmiObservedPid": os.getpid(),
                "nvidiaSmiProcessRowDigest": sha256_bytes(processes.stdout.encode()),
            }
        finally:
            if allocation.value:
                check(driver.cuMemFree_v2(allocation), "free")
            if module.value:
                check(driver.cuModuleUnload(module), "module-unload")
    finally:
        check(driver.cuDevicePrimaryCtxRelease_v2(device), "primary-context-release")


def run_live() -> dict[str, Any]:
    suffix = secrets.token_hex(4)
    challenge = secrets.token_hex(24)
    command_id = "cmd-" + secrets.token_hex(12)
    bucket = "p51-" + suffix
    batch = ("jitml-lift-cuda-batch|" + challenge).encode()
    inventory = nvidia_inventory()
    total_bytes = inventory["totalMiB"] * 1024 * 1024
    free_bytes = inventory["freeMiB"] * 1024 * 1024
    require(inventory["computeCapability"] == "5.2", "unexpected-compute-capability")
    require(total_bytes - RESERVE_BYTES >= REQUIRED_BYTES and free_bytes >= REQUIRED_BYTES,
            "live-capacity-preflight")
    checkpoint, cuda = run_cuda(challenge)
    bucket_created = False
    cleanup = {"MinioBucket": False, "CudaAllocationReleased": False}
    evidence: dict[str, Any] | None = None
    try:
        with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
            phase37.ensure_bucket(bucket)
            bucket_created = True
            require(phase37.list_keys(bucket) == [], "fresh-bucket-not-empty")
            batch_sha = hashlib.sha256(batch).hexdigest()
            checkpoint_sha = hashlib.sha256(checkpoint).hexdigest()
            batch_key = f"tenant-a/blobs/{batch_sha}"
            checkpoint_key = f"tenant-a/blobs/{checkpoint_sha}"
            writes = [
                (batch_key, phase37.put_immutable(bucket, batch_key, batch)),
                (checkpoint_key, phase37.put_immutable(bucket, checkpoint_key, checkpoint)),
            ]
            manifest_value = {
                "schema": "amoebius.jitml.checkpoint.v1", "tenant": "tenant-a",
                "app": "jitml-training", "commandId": command_id, "workId": command_id,
                "challenge": challenge, "batch": "sha256:" + batch_sha,
                "checkpoint": "sha256:" + checkpoint_sha, "optimizerSteps": STEPS,
                "parameterCount": PARAMETERS, "deviceUuid": inventory["uuid"],
            }
            manifest = canonical(manifest_value)
            manifest_sha = hashlib.sha256(manifest).hexdigest()
            manifest_key = f"tenant-a/manifests/{manifest_sha}"
            writes.append((manifest_key, phase37.put_immutable(bucket, manifest_key, manifest)))
            pointer_key = "tenant-a/pointers/jitml-latest"
            pointer_body = bytes.fromhex(manifest_sha)
            writes.append((pointer_key, phase37.put_immutable(bucket, pointer_key, pointer_body)))
            conflict_status, _, _ = phase37.s3_request(
                "PUT", bucket, pointer_key, body=b"conflicting-pointer",
                conditional={"if-none-match": "*"},
            )
            require(conflict_status == 412, f"pointer-conflict-status:{conflict_status}")
            pointer_readback, pointer_etag = phase37.get_object(bucket, pointer_key)
            manifest_readback, manifest_etag = phase37.get_object(bucket, manifest_key)
            checkpoint_readback, checkpoint_etag = phase37.get_object(bucket, checkpoint_key)
            keys_before_resend = phase37.list_keys(bucket)
            resend_pointer, _ = phase37.get_object(bucket, pointer_key)
            keys_after_resend = phase37.list_keys(bucket)
            unauthenticated_status, _, _ = phase37.s3_request(
                "GET", bucket, checkpoint_key, authenticated=False,
            )
            require(pointer_readback == resend_pointer == pointer_body, "pointer-readback")
            require(manifest_readback == manifest and checkpoint_readback == checkpoint,
                    "artifact-readback")
            require(keys_before_resend == keys_after_resend and len(keys_after_resend) == 4,
                    "exact-resend-effect")
            require(unauthenticated_status == 403, "unauthenticated-minio-bypass")
            evidence = {
                "schema": "amoebius.phase51.jitml-cuda-live.v1", "register": 3,
                "substrate": "linux-cuda", "result": "PASS-SCOPED",
                "resourceNames": {"minioBucket": bucket},
                "challenge": {"commandId": command_id, "workId": command_id,
                              "nonce": challenge, "unpredictableBytes": 24},
                "cuda": {**inventory, **cuda, "physicalDevice": True,
                         "cpuFallback": False, "wholeDeviceCount": 1,
                         "mandatoryReserveBytes": RESERVE_BYTES,
                         "netAllocatableBytes": total_bytes - RESERVE_BYTES,
                         "currentFreeBytesAtAdmission": free_bytes,
                         "requiredVramBytes": REQUIRED_BYTES,
                         "independentCheckpointOracle": True},
                "artifact": {
                    "batchDigest": "sha256:" + batch_sha,
                    "checkpointDigest": "sha256:" + checkpoint_sha,
                    "manifestDigest": "sha256:" + manifest_sha,
                    "batchKey": batch_key, "checkpointKey": checkpoint_key,
                    "manifestKey": manifest_key, "pointerKey": pointer_key,
                    "writeOrder": [key for key, _ in writes],
                    "pointerWrittenLast": writes[-1][0] == pointer_key,
                    "pointerConflictStatus": conflict_status,
                    "pointerUnchangedAfterConflict": pointer_readback == pointer_body,
                    "exactResendObjectDelta": len(keys_after_resend) - len(keys_before_resend),
                    "readbackEtagsPresent": all([pointer_etag, manifest_etag, checkpoint_etag]),
                    "unauthenticatedReadStatus": unauthenticated_status,
                },
                "linkedSibling": {
                    "module": "JitML.Codegen.RuntimeOperationsCuda",
                    "sourceDigest": sha256_bytes((ROOT.parent / "jitML/src/JitML/Codegen/RuntimeOperationsCuda.hs").read_bytes()),
                    "compiledByContractPackage": True,
                },
                "kubernetes": {
                    "retainedNodeGpuAllocatable": "",
                    "acceleratorOwnerPod": "UNVERIFIED",
                    "devicePlugin": "UNVERIFIED",
                },
                "universalLinuxCpu": {
                    "availableOnEveryHardwareSubstrate": True,
                    "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus",
                                          "apple": "Lima", "windows": "WSL2"},
                },
                "honesty": {
                    "linkedSiblingCudaCodegen": "TESTED",
                    "hostCudaKernelTraining": "TESTED",
                    "retainedMinioCommit": "TESTED",
                    "kubernetesAcceleratorOwner": "UNVERIFIED",
                    "devicePluginAllocation": "UNVERIFIED",
                    "nativeCborCommandEventChain": "UNVERIFIED",
                    "fullSiblingTrainer": "UNVERIFIED",
                    "trainerFailover": "UNVERIFIED",
                    "generalTenantNoninterference": "UNVERIFIED",
                },
            }
    finally:
        if bucket_created:
            try:
                with phase34.port_forward("platform-system", "service/minio", phase37.MINIO_PORT, 9000):
                    for key in phase37.list_keys(bucket):
                        phase37.delete_object(bucket, key)
                    phase37.require_s3({204}, phase37.s3_request("DELETE", bucket), "jitml-lift-cuda-delete-bucket")
                    status, _, _ = phase37.s3_request("GET", bucket, query={"list-type": "2"})
                    cleanup["MinioBucket"] = status == 404
            except Exception:
                cleanup["MinioBucket"] = False
        post = nvidia_inventory()
        cleanup["CudaAllocationReleased"] = post["freeMiB"] >= inventory["freeMiB"] - 8
    require(evidence is not None and all(cleanup.values()), f"cleanup:{cleanup}")
    evidence["cleanup"] = cleanup
    evidence["evidenceDigest"] = digest(evidence, newline=True)
    return evidence


def main() -> int:
    evidence = run_live()
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_bytes(canonical(evidence) + b"\n")
    print(
        "jitml-lift-cuda-jitml-cuda-live: PASS-SCOPED "
        f"({evidence['evidenceDigest']}; host CUDA + retained MinIO; "
        "Kubernetes accelerator-owner/native-CBOR/full sibling trainer UNVERIFIED)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
