import asyncio
import os
import json
import base64
from getpass import getpass
from typing import Any, Dict, List, Optional, Tuple, cast

import yaml
import aiohttp

from ..utils.async_command_runner import run_command
from ..secrets.encrypted_dict import encrypt_dict_to_file, decrypt_dict_from_file
from ..utils.terraform import read_terraform_state, get_output_from_state


async def initialize_vault(vault_addr: str, num_shares: int, threshold: int) -> Dict[str, str]:
    env = {"VAULT_ADDR": vault_addr}
    out = await run_command(
        ["vault", "operator", "init", f"-key-shares={num_shares}", f"-key-threshold={threshold}", "-format=json"],
        env=env
    )
    init_data_any = json.loads(out)
    init_data = cast(Dict[str, Any], init_data_any)
    unseal_keys_b64 = cast(List[str], init_data["unseal_keys_b64"])
    root_token = cast(str, init_data["root_token"])

    keys: Dict[str, str] = {f"unseal_key_{i+1}": k for i, k in enumerate(unseal_keys_b64)}
    keys["initial_root_token"] = root_token
    return keys


async def get_vault_pods(namespace: str) -> List[str]:
    pods_output = await run_command([
        "kubectl", "get", "pods",
        "-l", "app.kubernetes.io/name=vault",
        "-n", namespace,
        "-o", "jsonpath={.items[*].metadata.name}"
    ])
    return pods_output.strip().split()


async def unseal_vault_pods(unseal_keys: List[str], namespace: str, threshold: int = 1) -> None:
    pod_names = await get_vault_pods(namespace)

    async def run_unseal(pod: str, key: str) -> str:
        env = {"VAULT_ADDR": f"http://{pod}.{namespace}.svc.cluster.local:8200"}
        return await run_command(["vault", "operator", "unseal", key], env=env)

    tasks = [run_unseal(pod, key) for pod in pod_names for key in unseal_keys[:threshold]]
    await asyncio.gather(*tasks)


async def secret_exists(name: str, namespace: str) -> bool:
    try:
        await run_command(["kubectl", "get", "secret", name, "-n", namespace])
        return True
    except Exception:
        return False


async def configure_vault_tls(
    vault_addr: str,
    vault_token: str,
    common_name: str,
    ttl: str,
    namespace: str
) -> Dict[str, str]:
    env = {"VAULT_ADDR": vault_addr, "VAULT_TOKEN": vault_token}

    # Enable PKI if not enabled
    try:
        await run_command(["vault", "secrets", "enable", "pki"], env=env)
    except Exception:
        pass

    await run_command(["vault", "secrets", "tune", f"-max-lease-ttl={ttl}", "pki"], env=env)

    # Check if CA exists
    try:
        existing_ca = await run_command(["vault", "read", "pki/ca", "-format=json"], env=env)
        ca_data_any = json.loads(existing_ca)
        ca_data = cast(Dict[str, Any], ca_data_any)
        ca_cert = cast(str, ca_data["data"]["certificate"])
    except Exception:
        # Generate a new CA
        out = await run_command([
            "vault", "write", "-field=certificate", "pki/root/generate/internal",
            f"common_name={common_name}", f"ttl={ttl}"
        ], env=env)
        ca_cert = out.strip()

    # Configure URLs
    await run_command(["vault", "write", "pki/config/urls",
                       f"issuing_certificates={vault_addr}/v1/pki/ca",
                       f"crl_distribution_points={vault_addr}/v1/pki/crl"], env=env)

    # Create a role for TLS
    await run_command(["vault", "write", f"pki/roles/{common_name}",
                       f"allowed_domains={common_name}",
                       "allow_subdomains=true",
                       f"max_ttl={ttl}"], env=env)

    # Issue TLS cert if not exists
    if not await secret_exists("vault-server-tls", namespace):
        vault_cert_json = await run_command(
            ["vault", "write", "-format=json", f"pki/issue/{common_name}", f"common_name={common_name}", f"ttl={ttl}"],
            env=env
        )
        vault_cert_data_any = json.loads(vault_cert_json)
        vault_cert_data = cast(Dict[str, Any], vault_cert_data_any)
        data_field = cast(Dict[str, Any], vault_cert_data["data"])
        vault_crt = data_field["certificate"] + "\n" + data_field["issuing_ca"]
        vault_key = data_field["private_key"]

        secret_manifest: Dict[str, Any] = {
            'apiVersion': 'v1',
            'kind': 'Secret',
            'metadata': {
                'name': 'vault-server-tls',
                'namespace': namespace
            },
            'type': 'kubernetes.io/tls',
            'data': {
                'tls.crt': base64.b64encode(vault_crt.encode()).decode(),
                'tls.key': base64.b64encode(vault_key.encode()).decode()
            }
        }
        await run_command(["kubectl", "apply", "-f", "-"], input_data=yaml.dump(secret_manifest))

    return {"ca_cert": ca_cert}


async def install_cert_manager() -> None:
    async with aiohttp.ClientSession() as session:
        async with session.get('https://api.github.com/repos/jetstack/cert-manager/releases/latest') as resp:
            latest_release = await resp.json()
    if not isinstance(latest_release, dict):
        raise ValueError("Invalid release data from cert-manager API")
    version = cast(str, latest_release["tag_name"])
    url = f"https://github.com/jetstack/cert-manager/releases/download/{version}/cert-manager.yaml"
    await run_command(["kubectl", "apply", "--validate=false", "-f", url])
    deployments = ["cert-manager", "cert-manager-webhook", "cert-manager-cainjector"]
    for d in deployments:
        await run_command(["kubectl", "rollout", "status", f"deployment/{d}", "-n", "cert-manager", "--timeout=300s"])


async def configure_vault_for_cert_manager(vault_addr: str, vault_token: str, pki_role_name: str) -> None:
    env = {"VAULT_ADDR": vault_addr, "VAULT_TOKEN": vault_token}
    policy_hcl = f"""
path "pki/sign/{pki_role_name}" {{
  capabilities = ["create", "update"]
}}
"""
    await run_command(["vault", "policy", "write", "cert-manager-policy", "-"], input_data=policy_hcl, env=env)
    try:
        await run_command(["vault", "auth", "enable", "kubernetes"], env=env)
    except Exception:
        pass
    with open("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt", "r") as f:
        kube_ca_cert = f.read()
    with open("/var/run/secrets/kubernetes.io/serviceaccount/token", "r") as f:
        sa_token = f.read()
    kube_host = "https://kubernetes.default.svc"
    await run_command(["vault", "write", "auth/kubernetes/config",
                       f"kubernetes_host={kube_host}",
                       f"kubernetes_ca_cert={kube_ca_cert}",
                       f"token_reviewer_jwt={sa_token}"], env=env)
    await run_command(["vault", "write", "auth/kubernetes/role/cert-manager",
                       "bound_service_account_names=cert-manager",
                       "bound_service_account_namespaces=cert-manager",
                       "policies=cert-manager-policy",
                       "ttl=1h"], env=env)


async def create_cluster_issuer(vault_addr: str, ca_cert: str, pki_role_name: str) -> None:
    ca_cert_b64 = base64.b64encode(ca_cert.encode()).decode('utf-8')
    vault_issuer_manifest: Dict[str, Any] = {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'ClusterIssuer',
        'metadata': {'name': 'vault-issuer'},
        'spec': {
            'vault': {
                'path': f'pki/sign/{pki_role_name}',
                'server': vault_addr,
                'caBundle': ca_cert_b64,
                'auth': {
                    'kubernetes': {
                        'mountPath': '/v1/auth/kubernetes',
                        'role': 'cert-manager'
                    }
                }
            }
        }
    }
    await run_command(["kubectl", "apply", "-f", "-"], input_data=yaml.dump(vault_issuer_manifest))


async def create_linkerd_identity_certificate(
    namespace: str,
    common_name: str,
    duration: str,
    renew_before: str
) -> None:
    try:
        await run_command(["kubectl", "create", "namespace", namespace], sensitive=False)
    except Exception:
        # namespace may already exist
        pass
    cert_manifest: Dict[str, Any] = {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'Certificate',
        'metadata': {
            'name': 'linkerd-identity-issuer',
            'namespace': namespace
        },
        'spec': {
            'secretName': 'linkerd-identity-issuer',
            'duration': duration,
            'renewBefore': renew_before,
            'isCA': True,
            'commonName': common_name,
            'issuerRef': {
                'name': 'vault-issuer',
                'kind': 'ClusterIssuer'
            }
        }
    }
    await run_command(["kubectl", "apply", "-f", "-"], input_data=yaml.dump(cert_manifest))
    await run_command(["kubectl", "wait", "--for=condition=Ready", "certificate/linkerd-identity-issuer", "-n", namespace, "--timeout=300s"])


async def get_kubernetes_secret_data(secret_name: str, namespace: str, keys: List[str]) -> Dict[str, str]:
    async def get_decoded_data(key: str) -> Tuple[str, str]:
        base64_data = await run_command([
            "kubectl", "get", "secret", secret_name, "-n", namespace,
            "-o", f"jsonpath={{.data['{key}']}}"
        ])
        decoded = base64.b64decode(base64_data).decode('utf-8')
        return key, decoded

    pairs = await asyncio.gather(*[get_decoded_data(k) for k in keys])
    return {k: v for k, v in pairs}


async def install_linkerd(
    namespace: str,
    trust_anchor: str,
    issuer_crt: str,
    issuer_key: str
) -> None:
    env = {
        "LINKERD2_TRUST_ANCHORS_PEM": trust_anchor,
        "LINKERD2_CERT_PEM": issuer_crt,
        "LINKERD2_KEY_PEM": issuer_key
    }
    linkerd_manifest = await run_command(["linkerd", "install", "--identity-external-issuer"], env=env, sensitive=False)
    await run_command(["kubectl", "apply", "-f", "-"], input_data=linkerd_manifest)
    for dep in ["linkerd-controller", "linkerd-identity"]:
        await run_command(["kubectl", "rollout", "status", f"deployment/{dep}", "-n", namespace, "--timeout=300s"])


async def setup_certificate_renewals(
    vault_namespace: str,
    common_name: str,
    duration: str,
    renew_before: str
) -> None:
    cert_manifest: Dict[str, Any] = {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'Certificate',
        'metadata': {
            'name': 'vault-server-tls',
            'namespace': vault_namespace
        },
        'spec': {
            'secretName': 'vault-server-tls',
            'duration': duration,
            'renewBefore': renew_before,
            'commonName': common_name,
            'dnsNames': [
                common_name,
                'vault.vault.svc.cluster.local'
            ],
            'issuerRef': {
                'name': 'vault-issuer',
                'kind': 'ClusterIssuer'
            }
        }
    }
    await run_command(["kubectl", "apply", "-f", "-"], input_data=yaml.dump(cert_manifest))


async def wait_for_vault_pods_ready(namespace: str, timeout: str = "300s") -> None:
    await run_command([
        "kubectl", "rollout", "status", "statefulset/vault", "-n", namespace, f"--timeout={timeout}"
    ])


async def main(root_name: str = "vault") -> None:
    import pdb; pdb.set_trace()
    # Read terraform state
    state = await read_terraform_state(root_name)

    # Retrieve values from terraform outputs
    vault_namespace = get_output_from_state(state, "vault_namespace", str)
    vault_storage_class_name = get_output_from_state(state, "vault_storage_class_name", str)  # not directly used below, but available
    vault_replicas = get_output_from_state(state, "vault_replicas", int)
    

    # Additional configuration values
    pki_ttl = "8760h"
    cert_duration = "8760h"
    cert_renew_before = "720h"
    shamir_shares = 5
    shamir_threshold = 3
    vault_common_name = "vault.vault.svc.cluster.local"

    # Check if TLS secret exists (for idempotency)
    tls_secret_present = await secret_exists("vault-server-tls", vault_namespace)

    # Initial Helm install/upgrade
    helm_cmd = [
        "helm", "upgrade", "--install", "vault", "hashicorp/vault",
        "-n", vault_namespace,
        "--set", "server.ha.enabled=true",
        "--set", "server.ha.raft.enabled=true",
        "--set", "server.dataStorage.enabled=true",
        "--set", f"server.dataStorage.storageClass={vault_storage_class_name}",
        "--set", "injector.enabled=true",
        "--set", f"server.ha.raft.replicas={vault_replicas}"
    ]

    if tls_secret_present:
        helm_values: Dict[str, Any] = {
            'server': {
                'tls': {
                    'enabled': True,
                    'tlsSecret': 'vault-server-tls'
                }
            }
        }
        helm_values_yaml = yaml.dump(helm_values)
        await run_command(helm_cmd + ["-f", "-"], input_data=helm_values_yaml)
    else:
        await run_command(helm_cmd)

    await wait_for_vault_pods_ready(vault_namespace)

    pods = await get_vault_pods(vault_namespace)
    vault_init_addr = f"http://{pods[0]}.{vault_namespace}.svc.cluster.local:8200"
    vault_tls_addr = f"https://{vault_common_name}:8200"

    secrets_file_path = "/amoebius/data/vault_secrets.bin"
    if not os.path.exists(secrets_file_path):
        keys = await initialize_vault(vault_init_addr, shamir_shares, shamir_threshold)
        pw = getpass("Enter a new password to encrypt vault secrets: ")
        pw2 = getpass("Confirm password: ")
        while pw != pw2:
            print("Passwords do not match.")
            pw = getpass("Enter a new password to encrypt vault secrets: ")
            pw2 = getpass("Confirm password: ")
        encrypt_dict_to_file(keys, pw, secrets_file_path)
    else:
        pw = getpass("Enter password to decrypt vault secrets: ")
        keys = decrypt_dict_from_file(pw, secrets_file_path)

    unseal_keys = [v for k, v in keys.items() if k.startswith("unseal_key_")]
    await unseal_vault_pods(unseal_keys, vault_namespace, threshold=shamir_threshold)

    # Configure TLS and PKI
    tls_info = await configure_vault_tls(
        vault_tls_addr,
        keys['initial_root_token'],
        vault_common_name,
        pki_ttl,
        vault_namespace
    )

    # If TLS wasn't present before, enable now
    if not tls_secret_present:
        helm_values = {
            'server': {
                'tls': {
                    'enabled': True,
                    'tlsSecret': 'vault-server-tls'
                }
            }
        }
        helm_values_yaml = yaml.dump(helm_values)
        await run_command(["helm", "upgrade", "vault", "hashicorp/vault", "-n", vault_namespace, "-f", "-"], input_data=helm_values_yaml)
        await wait_for_vault_pods_ready(vault_namespace)
        await unseal_vault_pods(unseal_keys, vault_namespace, threshold=shamir_threshold)

    await install_cert_manager()
    await configure_vault_for_cert_manager(vault_tls_addr, keys['initial_root_token'], "linkerd-identity")

    await create_cluster_issuer(vault_tls_addr, tls_info['ca_cert'], "linkerd-identity")
    await create_linkerd_identity_certificate("linkerd", "identity.linkerd.cluster.local", cert_duration, cert_renew_before)

    secret_data = await get_kubernetes_secret_data("linkerd-identity-issuer", "linkerd", ['ca\\.crt', 'tls\\.crt', 'tls\\.key'])

    await install_linkerd("linkerd", secret_data['ca\\.crt'], secret_data['tls\\.crt'], secret_data['tls\\.key'])

    await run_command(["linkerd", "check"], sensitive=False)

    await setup_certificate_renewals(vault_namespace, vault_common_name, cert_duration, cert_renew_before)

    # Final helm upgrade to ensure TLS config stable
    helm_values = {
        'server': {
            'tls': {
                'enabled': True,
                'tlsSecret': 'vault-server-tls'
            }
        }
    }
    helm_values_yaml = yaml.dump(helm_values)
    await run_command(["helm", "upgrade", "vault", "hashicorp/vault", "-n", vault_namespace, "-f", "-"], input_data=helm_values_yaml)
    await wait_for_vault_pods_ready(vault_namespace)
    await unseal_vault_pods(unseal_keys, vault_namespace, threshold=shamir_threshold)

    print("Vault and Linkerd setup is complete using Terraform outputs.")


if __name__ == "__main__":
    # Adjust root_name if needed
    asyncio.run(main())
