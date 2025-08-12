# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Amoebius is a multi-cloud resilient computing platform designed for autonomous failover and recovery across geographically distributed environments. The system uses Kubernetes clusters in multiple locations connected by VPN, with automatic failover capabilities and federated MinIO storage for data synchronization.

## Development Commands

### Package Management
- Install dependencies: `poetry install`
- Update dependencies: `poetry update`

### CLI Tools
- **Local operations**: `./amoebloctl <command>` - Bash script for Kind cluster management
- **Python CLI**: `amoebctl <subcommand> [args...]` - Python CLI via Poetry for secrets/utils/providers
- The Python CLI uses a modular structure where subcommands are loaded from `python/amoebius/cli/`

### Docker Build
- Build and push multi-arch images: `./docker/build_and_push_image.sh`
- Build for ARM only: `./docker/build_and_push_image.sh --arm`
- Build for x86 only: `./docker/build_and_push_image.sh --x86`
- **Note**: Docker images currently reference `tuee22/amoebius:0.0.1` for existing deployments

### Testing
- Test modules are located in `python/amoebius/tests/`
- Run specific tests with: `python -m pytest python/amoebius/tests/<test_file>.py`

## Architecture Overview

### Core Components

1. **Python CLI (`amoebius.cli`)**:
   - Modular CLI system with subcommands for secrets, utils, and provider management
   - Entry point through `amoebctl` command (requires Poetry)

2. **Secrets Management (`amoebius.secrets`)**:
   - Vault integration via `AsyncVaultClient` for KV v2, transit encryption, and policy management
   - MinIO client integration for object storage
   - SSH key management and encrypted dictionaries
   - Follows "Zen of Amoebius" security principles (see `python/amoebius/secrets/zen_of_amoebius.md`)

3. **Deployment System (`amoebius.deployment`)**:
   - Multi-cloud provider deployment (AWS, Azure, GCP)
   - RKE2 Kubernetes cluster deployment
   - Terraform integration with MinIO-backed state storage

4. **Models (`amoebius.models`)**:
   - Pydantic models for configuration validation
   - AmoebiusTree hierarchical configuration with unique name validation
   - Provider-specific deployment models
   - Terraform backend configuration

5. **Utilities (`amoebius.utils`)**:
   - Async command execution with retry logic
   - Kubernetes operations
   - Terraform ephemeral storage and commands
   - SSH utilities and Docker integration

### Terraform Structure

- **Modules** (`terraform/modules/`):
  - `amoebius/`: Main Kubernetes deployment with Helm charts
  - `providers/`: Cloud-specific infrastructure (AWS, Azure, GCP)
  - `k8s/kind/`: Local Kind cluster setup
  - `ssh/`: SSH secret management

- **Roots** (`terraform/roots/`):
  - `providers/`: Provider-specific root configurations
  - `services/`: Service deployments (Vault, MinIO, Harbor)
  - `tests/`: Standalone deployment tests

## Security Model

The project follows the "Zen of Amoebius" security principles:
- Vault ("mom") is the trusted source of all secrets
- Secrets expire automatically and are never manually revoked
- Permanent secrets must be stored as ciphertext
- Bootstrap secrets in cleartext are only allowed for initialization
- All geolocations can function autonomously when disconnected

## Key Configuration Files

- `pyproject.toml`: Poetry configuration with Python 3.12 and core dependencies
- `python/amoebius/models/amoebius_config.py`: Main configuration model with nested hierarchy support
- Docker builds use multi-stage builds targeting `linux/amd64` and `linux/arm64`

## Development Patterns

- Uses async/await throughout for I/O operations
- Pydantic models for configuration validation and serialization
- Type hints with mypy support (`py.typed` marker file)
- Modular CLI design allowing easy extension of subcommands
- Provider abstraction layer supporting multiple cloud platforms

## Data Flow

1. Configuration defined using AmoebiusTree hierarchical structure
2. Secrets retrieved from Vault using AsyncVaultClient
3. Provider-specific infrastructure deployed via Terraform
4. Kubernetes clusters provisioned using RKE2
5. Services deployed using Helm charts
6. Data synchronized across geolocations using federated MinIO