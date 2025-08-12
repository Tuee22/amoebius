# Amoebius

Amoebius is a multi-cloud resilient computing platform designed for autonomous failover and recovery across geographically distributed environments. The system uses Kubernetes clusters in multiple locations connected by VPN, with automatic failover capabilities and federated MinIO storage for data synchronization.

## Features

- ✅ **Zero-downtime failover** between geolocations
- ✅ **Autonomous operation** when disconnected from parent clusters  
- ✅ **Federated data synchronization** via MinIO clusters
- ✅ **Hierarchical secret management** with Vault
- ✅ **Infrastructure as Code** with Terraform
- ✅ **Service mesh** for secure cross-cluster communication
- ✅ **Multi-cloud provider support** (AWS, Azure, GCP)
- ✅ **RKE2 Kubernetes distribution** for enhanced security

## Architecture Overview

### Core Components

1. **Python CLI (`amoebius.cli`)**:
   - Modular CLI system with subcommands for secrets, utils, and provider management  
   - Entry point through `amoebctl` command (requires Poetry installation)

2. **Secrets Management (`amoebius.secrets`)**:
   - Vault integration via `AsyncVaultClient` for KV v2, transit encryption, and policy management
   - MinIO client integration for object storage
   - SSH key management and encrypted dictionaries
   - Follows "Zen of Amoebius" security principles

3. **Deployment System (`amoebius.deployment`)**:
   - Multi-cloud provider deployment (AWS, Azure, GCP)
   - RKE2 Kubernetes cluster deployment
   - Terraform integration with MinIO-backed state storage

4. **Models (`amoebius.models`)**:
   - Pydantic models for configuration validation
   - AmoebiusTree hierarchical configuration with unique name validation
   - Provider-specific deployment models

### Hierarchical Cluster Structure

```
                    ┌─────────────────┐
                    │   Root Cluster  │
                    │    (Region A)   │
                    └─────────┬───────┘
                              │
                    ┌─────────▼───────┐
                    │   Spawns Child  │
                    │    Clusters     │
                    └─────┬─────┬─────┘
                          │     │
              ┌───────────▼─┐ ┌─▼───────────┐
              │  Child 1    │ │   Child 2   │
              │ (Region B)  │ │ (Region C)  │
              └─────────────┘ └─────────────┘
```

**Each cluster can:**
- Spawn new child clusters
- Operate autonomously when disconnected
- Reconnect and synchronize automatically

### Technology Stack

- **Kubernetes**: Container orchestration with RKE2 distribution
- **HashiCorp Vault**: Hierarchical secret management
- **Terraform**: Infrastructure as Code
- **Linkerd**: Service mesh for secure communication
- **MinIO**: Federated object storage
- **Python 3.12**: Core application runtime
- **Poetry**: Dependency management

## Prerequisites

- Docker (>= 27.5)
- Terraform (>= 1.10.0) 
- kubectl (>= 1.32)
- Cloud provider credentials (for multi-cloud deployments)

## Quick Start

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/matthewnowak/amoebius.git
   cd amoebius
   ```

2. **Check prerequisites:**
   ```bash
   ./amoebloctl check
   ```

3. **Deploy local Kind cluster:**
   ```bash
   ./amoebloctl up
   ```

4. **Check status:**
   ```bash
   ./amoebloctl status
   ```

5. **Initialize Vault (unseal):**
   ```bash
   ./amoebloctl unseal
   ```

6. **Open shell in container:**
   ```bash
   ./amoebloctl shell
   ```

7. **Clean up:**
   ```bash
   ./amoebloctl down
   ```

### Development with Poetry

For local Python development:

```bash
# Install dependencies
poetry install

# Activate virtual environment
poetry shell

# Run CLI directly
amoebctl --help
```

## Project Structure

```
amoebius/
├── python/amoebius/          # Python package
│   ├── cli/                  # CLI commands
│   ├── deployment/           # Deployment logic
│   ├── models/               # Pydantic models
│   ├── secrets/              # Secret management
│   ├── utils/                # Utilities
│   └── tests/                # Test suite
├── terraform/
│   ├── modules/              # Reusable Terraform modules
│   │   ├── amoebius/         # Main Kubernetes deployment
│   │   ├── providers/        # Cloud provider modules
│   │   └── k8s/kind/         # Local Kind setup
│   └── roots/                # Root configurations
│       ├── deploy/           # Deployment configs
│       ├── providers/        # Provider-specific roots
│       └── services/         # Service deployments
├── docker/                   # Docker build files
├── amoebloctl               # Main CLI script
└── pyproject.toml           # Poetry configuration
```

## Security Model: Zen of Amoebius

The project follows the "Zen of Amoebius" security principles:

- **Parent clusters are completely trusted** by their children
- **Children retain permission** to use secrets when parents are unreachable
- **Secrets expire automatically** and are never manually revoked
- **Permanent secrets stored as ciphertext** only
- **Bootstrap secrets in cleartext** only for initialization
- **All geolocations function autonomously** when disconnected
- **Short-expiring secrets preferred** over permanent ones
- **Secrets cannot be unseen, only expired**

## Available Commands

Amoebius provides **two CLI tools** for different purposes:

### `./amoebloctl` (Local Operations - Bash Script)

**Purpose**: Local development and Kind cluster management

- `./amoebloctl check` - Check prerequisites (Docker, Terraform, kubectl)
- `./amoebloctl up [--local-build]` - Deploy Kind cluster
- `./amoebloctl down` - Destroy Kind cluster  
- `./amoebloctl status` - Check cluster status
- `./amoebloctl unseal` - Initialize/unseal Vault
- `./amoebloctl shell` - Open shell in container

**Requirements**: Docker, Terraform, kubectl (no Poetry needed)

### `amoebctl` (Python CLI - via Poetry)

**Purpose**: Advanced secret management and cloud operations

- `amoebctl secrets` - Vault secret management operations
- `amoebctl utils` - Utility commands (kubectl, terraform helpers)
- `amoebctl providers` - Cloud provider operations (AWS, Azure, GCP)

**Requirements**: `poetry install` first, then available globally or in Poetry shell

**Usage**:
```bash
# Install first
poetry install

# Use directly
amoebctl --help

# Or in Poetry shell
poetry shell
amoebctl secrets --help
```

## Multi-Cloud Deployment

Amoebius supports deployment across:

- **AWS**: EC2, EKS, VPC
- **Azure**: VMs, AKS, Virtual Networks  
- **Google Cloud**: Compute Engine, GKE, VPC

Each provider has dedicated Terraform modules in `terraform/modules/providers/`.

## Development

### Testing

```bash
# Run tests
python -m pytest python/amoebius/tests/

# Type checking
mypy python/amoebius/ --strict
```

### Docker Build

```bash
# Build multi-arch images
./docker/build_and_push_image.sh

# Build ARM only
./docker/build_and_push_image.sh --arm

# Build x86 only
./docker/build_and_push_image.sh --x86
```

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Follow the existing code patterns
4. Add tests for new functionality
5. Submit a pull request

See `CLAUDE.md` for detailed development guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
