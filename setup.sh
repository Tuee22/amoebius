#!/usr/bin/env bash
#
# rename_cluster_config.sh
#
# This script:
#   1) Replaces /amoebius/python/amoebius/models/cluster_config.py with /amoebius/python/amoebius/models/cluster_deploy.py
#   2) In provider .py files (aws.py, azure.py, gcp.py), renames classes from *ClusterConfig -> *ClusterDeploy
#      and updates the base import to from "cluster_deploy import ClusterDeploy".
#   3) In /amoebius/python/amoebius/provider_deploy.py, renames references from "ClusterConfig" to "ClusterDeploy"
#      and from "cluster_config" to "cluster_deploy".
#   4) In /amoebius/python/amoebius/tests/provider_deployment.py, updates the references similarly, plus the provider-specific classes.
#
# Usage:
#   1) chmod +x rename_cluster_config.sh
#   2) ./rename_cluster_config.sh

set -e

BASE_DIR="/amoebius/python/amoebius"
MODELS_DIR="$BASE_DIR/models"
PROVIDERS_DIR="$MODELS_DIR/providers"

echo "Ensuring directories exist..."
mkdir -p "$PROVIDERS_DIR"

########################################
# 1) cluster_deploy.py (rename from cluster_config.py)
########################################
# Overwrite the old file with the new name and updated class name "ClusterDeploy"
cat << 'EOF' > "$MODELS_DIR/cluster_deploy.py"
"""
cluster_deploy.py

Contains:
  - InstanceGroup: submodel
  - ClusterDeploy: the base model (all fields required, no defaults).
"""

from typing import List, Dict, Optional
from pydantic import BaseModel

class InstanceGroup(BaseModel):
    """
    Submodel for instance_groups[]:
      {
        name           = string
        category       = string
        count_per_zone = number
        image          = optional(string, "")
      }
    """
    name: str
    category: str
    count_per_zone: int
    image: Optional[str] = None

class ClusterDeploy(BaseModel):
    """
    The base cluster "deploy" model, with all fields required, no defaults.

    Fields:
      region               : str
      vpc_cidr             : str
      availability_zones   : List[str]
      instance_type_map    : Dict[str, str]
      arm_default_image    : str
      x86_default_image    : str
      instance_groups      : List[InstanceGroup]
      ssh_user             : str
      vault_role_name      : str
      no_verify_ssl        : bool
    """
    region: str
    vpc_cidr: str
    availability_zones: List[str]
    instance_type_map: Dict[str, str]

    arm_default_image: str
    x86_default_image: str
    instance_groups: List[InstanceGroup]

    ssh_user: str
    vault_role_name: str
    no_verify_ssl: bool
EOF

echo "Created/overwrote $MODELS_DIR/cluster_deploy.py"


########################################
# 2) Provider-specific classes in aws.py, azure.py, gcp.py
#    rename them from *ClusterConfig -> *ClusterDeploy
#    and change the import from cluster_config -> cluster_deploy
########################################

# 2A) AWS
cat << 'EOF' > "$PROVIDERS_DIR/aws.py"
"""
aws.py

AWSClusterDeploy inherits from ClusterDeploy but fields are optional + AWS defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

# Updated import
from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class AWSClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="us-east-1")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["us-east-1a","us-east-1b","us-east-1c"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small": "t4g.micro",
        "x86_small": "t3.micro",
        "x86_medium": "t3.small",
        "nvidia_small": "g4dn.xlarge"
    })
    arm_default_image: Optional[str] = Field(default="ami-0faefad027f3b5de6")
    x86_default_image: Optional[str] = Field(default="ami-0c8a4fc5fa843b2c2")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="ubuntu")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
EOF

echo "Created/overwrote $PROVIDERS_DIR/aws.py"

# 2B) Azure
cat << 'EOF' > "$PROVIDERS_DIR/azure.py"
"""
azure.py

AzureClusterDeploy inherits from ClusterDeploy with optional fields + Azure defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class AzureClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="eastus")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["1","2","3"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small":    "Standard_D2ps_v5",
        "x86_small":    "Standard_D2s_v5",
        "x86_medium":   "Standard_D4s_v5",
        "nvidia_small": "Standard_NC4as_T4_v3"
    })
    arm_default_image: Optional[str] = Field(default="/subscriptions/123abc/.../24_04_arm")
    x86_default_image: Optional[str] = Field(default="/subscriptions/123abc/.../24_04_x86")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="azureuser")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
EOF

echo "Created/overwrote $PROVIDERS_DIR/azure.py"

# 2C) GCP
cat << 'EOF' > "$PROVIDERS_DIR/gcp.py"
"""
gcp.py

GCPClusterDeploy inherits from ClusterDeploy with optional fields + GCP defaults
"""

from typing import Optional, List, Dict
from pydantic import Field

from amoebius.models.cluster_deploy import ClusterDeploy, InstanceGroup

class GCPClusterDeploy(ClusterDeploy):
    region: Optional[str] = Field(default="us-central1")
    vpc_cidr: Optional[str] = Field(default="10.0.0.0/16")
    availability_zones: Optional[List[str]] = Field(default=["us-central1-a","us-central1-b","us-central1-f"])
    instance_type_map: Optional[Dict[str, str]] = Field(default={
        "arm_small": "t2a-standard-1",
        "x86_small": "e2-small",
        "x86_medium": "e2-standard-4",
        "nvidia_small": "a2-highgpu-1g"
    })
    arm_default_image: Optional[str] = Field(default="projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-arm64")
    x86_default_image: Optional[str] = Field(default="projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts")
    instance_groups: Optional[List[InstanceGroup]] = Field(default=[])
    ssh_user: Optional[str] = Field(default="ubuntu")
    vault_role_name: Optional[str] = Field(default="amoebius-admin-role")
    no_verify_ssl: Optional[bool] = Field(default=True)
EOF

echo "Created/overwrote $PROVIDERS_DIR/gcp.py"

########################################
# 3) /amoebius/python/amoebius/provider_deploy.py
#    rename references from "ClusterConfig" -> "ClusterDeploy"
#    from "cluster_config" -> "cluster_deploy"
########################################
cat << 'EOF' > "$BASE_DIR/provider_deploy.py"
"""
provider_deploy.py

Now 'deploy(...)' expects a 'cluster_deploy: ClusterDeploy' param,
and we do cluster_deploy.model_dump() to pass to terraform.
"""

import json
from typing import Any
from enum import Enum

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.api_keys import AWSApiKey, AzureCredentials, GCPServiceAccountKey
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.utils.terraform import (
    init_terraform,
    apply_terraform,
    destroy_terraform,
)

class ProviderName(str, Enum):
    aws = "aws"
    azure = "azure"
    gcp = "gcp"

async def get_provider_env_from_vault(provider: ProviderName, vault_client: AsyncVaultClient, vault_path: str) -> dict:
    secret_data = await vault_client.read_secret(vault_path)

    if provider == ProviderName.aws:
        aws_creds = AWSApiKey(**secret_data)
        env = {
            "AWS_ACCESS_KEY_ID": aws_creds.access_key_id,
            "AWS_SECRET_ACCESS_KEY": aws_creds.secret_access_key,
        }
        if aws_creds.session_token:
            env["AWS_SESSION_TOKEN"] = aws_creds.session_token
        return env

    elif provider == ProviderName.azure:
        az_creds = AzureCredentials(**secret_data)
        return {
            "ARM_CLIENT_ID": az_creds.client_id,
            "ARM_CLIENT_SECRET": az_creds.client_secret,
            "ARM_TENANT_ID": az_creds.tenant_id,
            "ARM_SUBSCRIPTION_ID": az_creds.subscription_id,
        }

    elif provider == ProviderName.gcp:
        gcp_creds = GCPServiceAccountKey(**secret_data)
        return {
            "GOOGLE_CREDENTIALS": json.dumps(gcp_creds.model_dump()),
            "GOOGLE_PROJECT": gcp_creds.project_id,
        }

    else:
        raise ValueError(f"Unknown provider: {provider}")

async def deploy(
    provider: ProviderName,
    vault_client: AsyncVaultClient,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    destroy: bool = False,
) -> None:
    """
    1) get env from get_provider_env_from_vault
    2) cluster_deploy.model_dump() => dict for TF
    3) run terraform init+apply or destroy
    """
    env_vars = await get_provider_env_from_vault(provider, vault_client, vault_path)
    tf_vars = cluster_deploy.model_dump()

    root_name = f"providers/{provider}"

    if destroy:
        print(f"[{provider}] => Running destroy with variables = {tf_vars}")
        await destroy_terraform(root_name, env=env_vars, variables=tf_vars, sensitive=False)
    else:
        print(f"[{provider}] => init+apply with variables = {tf_vars}")
        await init_terraform(root_name, env=env_vars, reconfigure=True, sensitive=False)
        await apply_terraform(root_name, env=env_vars, variables=tf_vars, sensitive=False)

    print(f"[{provider}] => done (destroy={destroy}).")
EOF

echo "Overwrote $BASE_DIR/provider_deploy.py"

########################################
# 4) /amoebius/python/amoebius/tests/provider_deployment.py
#    rename references from cluster_config -> cluster_deploy
#    from *ClusterConfig -> *ClusterDeploy
########################################
cat << 'EOF' > "$BASE_DIR/tests/provider_deployment.py"
#!/usr/bin/env python3
"""
provider_deployment.py

A script that parses CLI arguments, picks a provider-specific *ClusterDeploy class
(AWSClusterDeploy, AzureClusterDeploy, GCPClusterDeploy), merges user overrides,
and calls deploy(...).
"""

import sys
import json
import argparse
import asyncio
from typing import Dict, Any, NoReturn

from amoebius.secrets.vault_client import AsyncVaultClient
from amoebius.models.vault import VaultSettings

# The base cluster deploy, plus provider-specific classes
from amoebius.models.cluster_deploy import ClusterDeploy
from amoebius.models.providers.aws import AWSClusterDeploy
from amoebius.models.providers.azure import AzureClusterDeploy
from amoebius.models.providers.gcp import GCPClusterDeploy

from amoebius.provider_deploy import deploy, ProviderName

def parse_keyvals(args_list) -> Dict[str, str]:
    output: Dict[str, str] = {}
    for item in args_list:
        if "=" in item:
            k,v = item.split("=",1)
            output[k] = v
        else:
            output[item] = "True"
    return output

async def run_deployment(
    provider: ProviderName,
    vault_settings: VaultSettings,
    vault_path: str,
    cluster_deploy: ClusterDeploy,
    destroy: bool
):
    async with AsyncVaultClient(vault_settings) as vc:
        await deploy(
            provider=provider,
            vault_client=vc,
            vault_path=vault_path,
            cluster_deploy=cluster_deploy,
            destroy=destroy
        )

def main() -> NoReturn:
    parser = argparse.ArgumentParser(
        description=(
            "Deploy or destroy a cluster for AWS, Azure, or GCP with a cluster_deploy object "
            "and provider-based defaults."
        )
    )
    parser.add_argument("--provider", choices=["aws","azure","gcp"], required=True)
    parser.add_argument("--vault-path", required=True)
    parser.add_argument("--destroy", action="store_true")
    parser.add_argument("--vault-args", nargs="*", default=[], help="Vault settings like verify_ssl=False, etc.")
    parser.add_argument("--cluster-args", nargs="*", default=[], help="Override fields in cluster deploy, e.g. region=us-east-1")
    args = parser.parse_args()

    # 1) Vault Settings
    from amoebius.models.vault import VaultSettings
    vdict = parse_keyvals(args.vault_args)
    vs = VaultSettings(**vdict)

    # 2) Build a provider-specific cluster deploy object
    # parse cluster-args as dict
    cargs_str = parse_keyvals(args.cluster_args)
    cargs: Dict[str, Any] = {}
    for k,v in cargs_str.items():
        val = v.strip()
        if (val.startswith("{") and val.endswith("}")) or (val.startswith("[") and val.endswith("]")):
            try:
                cargs[k] = json.loads(val)
            except:
                cargs[k] = val
        else:
            cargs[k] = val

    provider_enum = ProviderName(args.provider)
    if provider_enum == ProviderName.aws:
        cluster_obj = AWSClusterDeploy(**cargs)
    elif provider_enum == ProviderName.azure:
        cluster_obj = AzureClusterDeploy(**cargs)
    elif provider_enum == ProviderName.gcp:
        cluster_obj = GCPClusterDeploy(**cargs)
    else:
        print(f"Unknown provider {provider_enum}", file=sys.stderr)
        sys.exit(1)

    # 3) Kick off deployment
    try:
        asyncio.run(
            run_deployment(
                provider=provider_enum,
                vault_settings=vs,
                vault_path=args.vault_path,
                cluster_deploy=cluster_obj,
                destroy=args.destroy
            )
        )
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
EOF

chmod +x "$BASE_DIR/tests/provider_deployment.py"

echo ""
echo "All done!"
echo "Renamed references from 'cluster_config' to 'cluster_deploy', from 'ClusterConfig' to 'ClusterDeploy'."
echo "Renamed provider classes from e.g. 'AWSClusterConfig' to 'AWSClusterDeploy'."
echo "Updated /amoebius/python/amoebius/provider_deploy.py to accept 'cluster_deploy: ClusterDeploy'."
echo "Updated /amoebius/python/amoebius/tests/provider_deployment.py accordingly."
echo "Enjoy!"