import asyncio
import base64
import json
import os
from typing import Any, Dict, List, Optional, Tuple
from ..utils.async_command_runner import run_command, CommandError

import yaml  # PyYAML library for YAML handling
import aiohttp  # For making asynchronous HTTP requests

async def install_vault(
    namespace: str,
    helm_values: Dict[str, Any]
) -> None:
    """
    Install Vault using Helm in the specified namespace.

    Args:
        namespace: Kubernetes namespace where Vault should be installed.
        helm_values: Helm values for configuring Vault.

    Returns:
        None
    """
    await run_command(["helm", "repo", "add", "hashicorp", "https://helm.releases.hashicorp.com"])
    await run_command(["helm", "repo", "update"])
    await run_command(["kubectl", "create", "namespace", namespace])
    await run_command(
        ["helm", "install", "vault", "hashicorp/vault", "-n", namespace, "-f", "-"],
        input_data=yaml.dump(helm_values)
    )
    await wait_for_rollout("statefulset", "vault", namespace)


async def initialize_vault(
    vault_addr: str,
    num_shares: int,
    threshold: int
) -> Dict[str, str]:
    """
    Initialize Vault and return the unseal keys and root token.

    Args:
        vault_addr: Address of the Vault server.
        num_shares: Total number of unseal keys to generate.
        threshold: Number of unseal keys required to unseal Vault.

    Returns:
        A dictionary containing unseal keys and the initial root token.

    Raises:
        Exception: If initialization fails or required keys are missing.
    """
    env = {"VAULT_ADDR": vault_addr}
    init_output = await run_command(
        ["vault", "operator", "init", f"-key-shares={num_shares}", f"-key-threshold={threshold}", "-format=json"],
        env=env
    )
    init_data = json.loads(init_output)
    keys = {
        **{f"Unseal Key {i+1}": key for i, key in enumerate(init_data['unseal_keys_b64'])},
        'Initial Root Token': init_data['root_token']
    }
    required_keys = [f'Unseal Key {i+1}' for i in range(1, num_shares + 1)] + ['Initial Root Token']
    if not all(k in keys for k in required_keys):
        raise Exception("Failed to retrieve Unseal Keys or Root Token from init output.")
    return keys


async def unseal_vault_pods(
    vault_addr: str,
    unseal_keys: List[str],
    namespace: str,
    threshold: int
) -> None:
    """
    Unseal Vault pods in the specified namespace using the provided unseal keys.

    Args:
        vault_addr: Address of the Vault server.
        unseal_keys: List of unseal keys.
        namespace: Kubernetes namespace where Vault is deployed.
        threshold: Number of unseal keys required to unseal Vault.

    Returns:
        None
    """
    env = {"VAULT_ADDR": vault_addr}
    pod_names_output = await run_command([
        "kubectl", "get", "pods",
        "-l", "app.kubernetes.io/name=vault",
        "-n", namespace,
        "-o", "jsonpath={.items[*].metadata.name}"
    ])
    pod_names = pod_names_output.strip().split()
    unseal_tasks = [
        run_command(
            [
                "kubectl", "exec", "-n", namespace, pod_name, "--",
                "vault", "operator", "unseal", key
            ],
            env=env
        )
        for pod_name in pod_names
        for key in unseal_keys[:threshold]
    ]
    await asyncio.gather(*unseal_tasks)


async def unseal_vault_pods_concurrently(
    vault_addr_list: List[str],
    unseal_keys: List[str],
    namespace: str,
    threshold: int
) -> None:
    """
    Unseal multiple Vault pods concurrently in the specified namespace using the provided unseal keys.

    Args:
        vault_addr_list: List of pod names to unseal.
        unseal_keys: List of unseal keys.
        namespace: Kubernetes namespace where Vault is deployed.
        threshold: Number of unseal keys required to unseal Vault.

    Returns:
        None
    """
    async def unseal_single_pod(vault_addr: str)->None:
        await unseal_vault_pods(
            vault_addr=vault_addr,
            unseal_keys=unseal_keys,
            namespace=namespace,
            threshold=threshold
        )

    # Schedule unseal tasks concurrently for all pods in the list.
    tasks = [unseal_single_pod(pod_name) for pod_name in vault_addr_list]
    await asyncio.gather(*tasks)


async def configure_vault_tls(
    vault_addr: str,
    vault_token: str,
    common_name: str,
    ttl: str,
    namespace: str
) -> Dict[str, str]:
    """
    Enable the PKI secrets engine and configure Vault to use its own TLS certificates.

    Args:
        vault_addr: Address of the Vault server.
        vault_token: Root token for authenticating with Vault.
        common_name: Common Name for the TLS certificate.
        ttl: Time-to-live for the certificates.
        namespace: Kubernetes namespace where Vault is deployed.

    Returns:
        A dictionary containing the CA certificate.

    Raises:
        CommandError: If any Vault command fails.
    """
    env = {"VAULT_ADDR": vault_addr, "VAULT_TOKEN": vault_token}

    # Enable the PKI secrets engine at the default path 'pki'
    await run_command(["vault", "secrets", "enable", "pki"], env=env)

    # Tune the PKI secrets engine to set the maximum lease TTL
    await run_command(["vault", "secrets", "tune", f"-max-lease-ttl={ttl}", "pki"], env=env)

    # Generate a self-signed root certificate and save the certificate
    ca_cert = await run_command(
        [
            "vault", "write", "-field=certificate", "pki/root/generate/internal",
            f"common_name={common_name}",
            f"ttl={ttl}"
        ],
        env=env
    )

    # Configure the URLs for issuing certificates and CRL distribution points
    await run_command(
        [
            "vault", "write", "pki/config/urls",
            f"issuing_certificates={vault_addr}/v1/pki/ca",
            f"crl_distribution_points={vault_addr}/v1/pki/crl"
        ],
        env=env
    )

    # Create a role named after the common name to issue certificates for the Vault server
    await run_command(
        [
            "vault", "write", f"pki/roles/{common_name}",
            f"allowed_domains={common_name}",
            "allow_subdomains=true",
            f"max_ttl={ttl}"
        ],
        env=env
    )

    # Issue a certificate for the Vault server using the PKI role created above
    vault_cert_json = await run_command(
        [
            "vault", "write", "-format=json", f"pki/issue/{common_name}",
            f"common_name={common_name}",
            f"ttl={ttl}"
        ],
        env=env
    )
    # Parse the issued certificate and private key
    vault_cert_data = json.loads(vault_cert_json)['data']
    vault_crt = '\n'.join([vault_cert_data['certificate'], vault_cert_data['issuing_ca']])
    vault_key = vault_cert_data['private_key']

    # Create a Kubernetes Secret to store the TLS certificate and key
    secret_manifest = {
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
    await apply_manifest(secret_manifest)
    return {"ca_cert": ca_cert}


async def install_cert_manager() -> None:
    """
    Install the latest version of cert-manager in the Kubernetes cluster.

    Returns:
        None
    """
    # Fetch the latest release version of cert-manager from GitHub API
    async with aiohttp.ClientSession() as session:
        async with session.get('https://api.github.com/repos/jetstack/cert-manager/releases/latest') as resp:
            latest_release = await resp.json()
            version = latest_release['tag_name']

    # Construct the URL to the cert-manager installation manifest
    url = f"https://github.com/jetstack/cert-manager/releases/download/{version}/cert-manager.yaml"

    # Install cert-manager using the latest version
    await run_command([
        "kubectl", "apply", "--validate=false", "-f", url
    ])

    # Wait for cert-manager components to be ready
    deployments = ["cert-manager", "cert-manager-webhook", "cert-manager-cainjector"]
    await asyncio.gather(*[
        wait_for_rollout("deployment", deployment, "cert-manager")
        for deployment in deployments
    ])


async def configure_vault_for_cert_manager(
    vault_addr: str,
    vault_token: str,
    pki_role_name: str,
    cert_manager_namespace: str = "cert-manager"
) -> None:
    """
    Configure Vault to work with cert-manager for certificate issuance.

    Args:
        vault_addr: Address of the Vault server.
        vault_token: Root token for authenticating with Vault.
        pki_role_name: Name of the PKI role in Vault.
        cert_manager_namespace: Namespace where cert-manager is deployed.

    Returns:
        None
    """
    env = {"VAULT_ADDR": vault_addr, "VAULT_TOKEN": vault_token}
    policy_hcl = f"""
path "pki/sign/{pki_role_name}" {{
  capabilities = ["create", "update"]
}}
"""
    # Write a policy named 'cert-manager-policy' to allow signing certificates with the specified role
    await run_command(["vault", "policy", "write", "cert-manager-policy", "-"], input_data=policy_hcl, env=env)

    # Enable the Kubernetes authentication method in Vault
    await run_command(["vault", "auth", "enable", "kubernetes"], env=env)
    # Read Kubernetes service account credentials for configuring Vault Kubernetes auth
    with open("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt", "r") as f:
        kube_ca_cert = f.read()
    with open("/var/run/secrets/kubernetes.io/serviceaccount/token", "r") as f:
        sa_token = f.read()
    kube_host = "https://kubernetes.default.svc"

    # Configure the Kubernetes auth method with the cluster's details
    await run_command(
        [
            "vault", "write", "auth/kubernetes/config",
            f"kubernetes_host={kube_host}",
            f"kubernetes_ca_cert={kube_ca_cert}",
            f"token_reviewer_jwt={sa_token}"
        ],
        env=env
    )

    # Create a role named 'cert-manager' for cert-manager to authenticate with Vault
    await run_command(
        [
            "vault", "write", "auth/kubernetes/role/cert-manager",
            "bound_service_account_names=cert-manager",
            f"bound_service_account_namespaces={cert_manager_namespace}",
            "policies=cert-manager-policy",
            "ttl=1h"
        ],
        env=env
    )


async def create_cluster_issuer(
    vault_addr: str,
    ca_cert: str,
    pki_role_name: str
) -> None:
    """
    Create a ClusterIssuer resource in cert-manager that uses Vault.

    Args:
        vault_addr: Address of the Vault server.
        ca_cert: CA certificate in PEM format.
        pki_role_name: Name of the PKI role in Vault.

    Returns:
        None
    """
    ca_cert_b64 = base64.b64encode(ca_cert.encode()).decode('utf-8')
    vault_issuer_manifest = {
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
    await apply_manifest(vault_issuer_manifest)


async def create_linkerd_identity_certificate(
    namespace: str,
    common_name: str,
    duration: str,
    renew_before: str
) -> None:
    """
    Create a Certificate resource for Linkerd identity issuer.

    Args:
        namespace: Kubernetes namespace where Linkerd is deployed.
        common_name: Common Name for the certificate.
        duration: Duration of the certificate's validity.
        renew_before: Time before expiration to renew the certificate.

    Returns:
        None
    """
    # Create the namespace if it doesn't exist
    await run_command(["kubectl", "create", "namespace", namespace])
    # Define the Certificate manifest for Linkerd identity issuer
    linkerd_identity_issuer_manifest = {
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
    await apply_manifest(linkerd_identity_issuer_manifest)

    # Wait for the Certificate to be ready
    await run_command([
        "kubectl", "wait", "--for=condition=Ready", "certificate/linkerd-identity-issuer",
        "-n", namespace, "--timeout=300s"
    ])


async def install_linkerd(
    namespace: str,
    trust_anchor: str,
    issuer_crt: str,
    issuer_key: str
) -> None:
    """
    Install Linkerd control plane using an external issuer.

    Args:
        namespace: Kubernetes namespace where Linkerd is deployed.
        trust_anchor: Trust anchor certificate in PEM format.
        issuer_crt: Issuer certificate in PEM format.
        issuer_key: Issuer private key in PEM format.

    Returns:
        None
    """
    env = {
        "LINKERD2_TRUST_ANCHORS_PEM": trust_anchor,
        "LINKERD2_CERT_PEM": issuer_crt,
        "LINKERD2_KEY_PEM": issuer_key
    }
    linkerd_install_cmd = [
        "linkerd", "install",
        "--identity-external-issuer"
    ]
    # Generate the Linkerd manifest using the provided certificates
    linkerd_manifest = await run_command(linkerd_install_cmd, env=env, sensitive=False)
    # Apply the Linkerd manifest to install the control plane
    await run_command(["kubectl", "apply", "-f", "-"], input_data=linkerd_manifest)
    deployments = ["linkerd-controller", "linkerd-identity"]
    # Wait for Linkerd deployments to be ready
    await asyncio.gather(*[
        wait_for_rollout("deployment", deployment, namespace)
        for deployment in deployments
    ])


async def setup_certificate_renewals(
    vault_namespace: str,
    common_name: str,
    duration: str,
    renew_before: str
) -> None:
    """
    Set up automatic certificate renewals for Vault's TLS certificates.

    Args:
        vault_namespace: Kubernetes namespace where Vault is deployed.
        common_name: Common Name for the TLS certificate.
        duration: Duration of the certificate's validity.
        renew_before: Time before expiration to renew the certificate.

    Returns:
        None
    """
    vault_server_cert_manifest = {
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
    await apply_manifest(vault_server_cert_manifest)


async def wait_for_rollout(
    resource_type: str,
    name: str,
    namespace: str,
    timeout: str = "300s"
) -> None:
    """
    Wait for a Kubernetes resource to complete its rollout.

    Args:
        resource_type: Type of the resource (e.g., 'deployment', 'statefulset').
        name: Name of the resource.
        namespace: Kubernetes namespace where the resource is deployed.
        timeout: Timeout duration for the rollout to complete.

    Returns:
        None
    """
    await run_command([
        "kubectl", "rollout", "status",
        f"{resource_type}/{name}",
        "-n", namespace,
        f"--timeout={timeout}"
    ])


async def apply_manifest(manifest: Dict[str, Any]) -> None:
    """
    Apply a Kubernetes manifest.

    Args:
        manifest: The Kubernetes manifest as a dictionary.

    Returns:
        None
    """
    await run_command(["kubectl", "apply", "-f", "-"], input_data=yaml.dump(manifest))


async def get_kubernetes_secret_data(
    secret_name: str,
    namespace: str,
    keys: List[str]
) -> Dict[str, str]:
    """
    Retrieve and decode data from a Kubernetes secret.

    Args:
        secret_name: Name of the Kubernetes secret.
        namespace: Namespace where the secret is located.
        keys: List of keys to retrieve from the secret's data.

    Returns:
        A dictionary mapping keys to their decoded values.

    Raises:
        CommandError: If the kubectl command fails.
    """
    async def get_decoded_data(key: str) -> Tuple[str, str]:
        base64_data = await run_command([
            "kubectl", "get", "secret", secret_name, "-n", namespace,
            "-o", f"jsonpath={{.data['{key}']}}"
        ])
        decoded_data = base64.b64decode(base64_data).decode('utf-8')
        return key, decoded_data

    key_value_pairs = await asyncio.gather(*[get_decoded_data(key) for key in keys])
    return dict(key_value_pairs)


async def setup_vault_and_linkerd(
    vault_namespace: str = "vault",
    vault_replicas: int = 3,
    shamir_shares: int = 1,
    shamir_threshold: int = 1,
    vault_common_name: str = "vault.vault.svc.cluster.local",
    pki_ttl: str = "8760h",  # 1 year
    cert_duration: str = "8760h",  # 1 year
    cert_renew_before: str = "720h",  # 30 days
    pki_role_name: str = "linkerd-identity",
    linkerd_namespace: str = "linkerd",
    linkerd_common_name: str = "identity.linkerd.cluster.local"
) -> Dict[str, Any]:
    """
    Set up Vault and Linkerd with mutual TLS and automatic certificate renewal.

    Args:
        vault_namespace: Kubernetes namespace for Vault.
        vault_replicas: Number of Vault replicas to deploy.
        shamir_shares: Total number of unseal keys to generate.
        shamir_threshold: Number of unseal keys required to unseal Vault.
        vault_common_name: Common Name for Vault's TLS certificate.
        pki_ttl: Time-to-live for the PKI certificates.
        cert_duration: Duration of the certificates' validity.
        cert_renew_before: Time before expiration to renew the certificates.
        pki_role_name: Name of the PKI role in Vault.
        linkerd_namespace: Kubernetes namespace for Linkerd.
        linkerd_common_name: Common Name for Linkerd's identity certificate.

    Returns:
        A dictionary containing the Vault unseal keys and root token.
    """
    vault_addr = f"https://{vault_common_name}:8200"
    vault_helm_values = {
        'server': {
            'ha': {
                'enabled': True,
                'replicas': vault_replicas
            },
            'tls': {
                'enabled': False
            },
            'dataStorage': {
                'enabled': True
            },
            'injector': {
                'enabled': True
            }
        }
    }
    try:
        # Install Vault using Helm
        await install_vault(vault_namespace, vault_helm_values)

        # Initialize Vault and retrieve unseal keys and root token
        keys = await initialize_vault(
            vault_addr.replace("https", "http"),
            shamir_shares,
            shamir_threshold
        )

        # Unseal the Vault pods using the unseal keys
        unseal_keys = [keys[key_name] for key_name in keys if key_name.startswith("Unseal Key")]
        await unseal_vault_pods(
            vault_addr.replace("https", "http"),
            unseal_keys,
            vault_namespace,
            shamir_threshold
        )

        # Configure Vault to use its own TLS certificates
        tls_info = await configure_vault_tls(
            vault_addr,
            keys['Initial Root Token'],
            vault_common_name,
            pki_ttl,
            vault_namespace
        )

        # Update Vault Helm values to enable TLS and use the generated TLS secret
        vault_helm_values_tls = {
            **vault_helm_values,
            'server': {
                **vault_helm_values['server'],
                'tls': {
                    'enabled': True,
                    'tlsSecret': 'vault-server-tls'
                }
            }
        }
        await run_command(
            ["helm", "upgrade", "vault", "hashicorp/vault", "-n", vault_namespace, "-f", "-"],
            input_data=yaml.dump(vault_helm_values_tls)
        )
        await wait_for_rollout("statefulset", "vault", vault_namespace)

        # Install cert-manager
        await install_cert_manager()

        # Configure Vault to work with cert-manager
        await configure_vault_for_cert_manager(
            vault_addr,
            keys['Initial Root Token'],
            pki_role_name
        )

        # Create a ClusterIssuer in cert-manager using Vault
        await create_cluster_issuer(vault_addr, tls_info['ca_cert'], pki_role_name)

        # Create a Certificate for Linkerd identity issuer
        await create_linkerd_identity_certificate(
            linkerd_namespace,
            linkerd_common_name,
            cert_duration,
            cert_renew_before
        )

        # Retrieve the Linkerd trust anchors and issuer certificates from the secret
        secret_data = await get_kubernetes_secret_data(
            "linkerd-identity-issuer",
            linkerd_namespace,
            ['ca\\.crt', 'tls\\.crt', 'tls\\.key']
        )
        linkerd_trust_anchor_crt = secret_data['ca\\.crt']
        issuer_crt = secret_data['tls\\.crt']
        issuer_key = secret_data['tls\\.key']

        # Install Linkerd using the external issuer
        await install_linkerd(
            linkerd_namespace,
            linkerd_trust_anchor_crt,
            issuer_crt,
            issuer_key
        )

        # Verify the Linkerd installation
        await run_command(["linkerd", "check"], sensitive=False)

        # Set up automatic certificate renewals for Vault's TLS certificates
        await setup_certificate_renewals(
            vault_namespace,
            vault_common_name,
            cert_duration,
            cert_renew_before
        )

        # Upgrade Vault to ensure it uses the managed TLS secret
        await run_command(
            ["helm", "upgrade", "vault", "hashicorp/vault", "-n", vault_namespace, "-f", "-"],
            input_data=yaml.dump(vault_helm_values_tls)
        )

        return {
            "vault_unseal_keys": unseal_keys,
            "vault_root_token": keys['Initial Root Token']
        }

    except CommandError as ce:
        print(f"An error occurred: {ce}")
        return {}
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return {}


async def main() -> None:
    """
    Main function to execute the setup and print out the Vault unseal keys and root token.

    Returns:
        None
    """
    secrets = await setup_vault_and_linkerd()
    if secrets:
        print("Vault Unseal Keys and Root Token:")
        for idx, key in enumerate(secrets["vault_unseal_keys"], start=1):
            print(f"Unseal Key {idx}: {key}")
        print(f"Initial Root Token: {secrets['vault_root_token']}")
    else:
        print("Failed to retrieve Vault secrets.")


if __name__ == "__main__":
    asyncio.run(main())
