
# Amoebius

Amoebius is a robust and resilient multi-cloud computing project designed for seamless failover and autonomous recovery across geographically distributed cloud environments. With a foundation in Kubernetes, Terraform, and Linkerd, this project ensures high availability and fault tolerance by dynamically adapting services across geolocations.

## Features

- **Multi-cloud setup**: Uses Terraform to provision environments across multiple cloud providers or physical locations.
- **VPN Connectivity**: Ties different geolocations together using a VPN for secure communication.
- **Kubernetes-based**: Each geolocation runs its own Kubernetes cluster, ensuring high scalability and management.
- **Zero-downtime Failover**: Services in one location will instantly failover to another in the event of a VPN disconnect, ensuring uninterrupted availability.
- **Autonomous Functionality**: Disconnected geolocations can continue to function autonomously, spinning up necessary services and resuming normal operations when reconnected.
- **MinIO Federated Cluster**: Upon reconnection, geolocations will synchronize all shared data via a federated MinIO cluster.

## Architecture

1. **Terraform** provisions cloud and physical environments in different geolocations.
2. **VPN** ensures secure and consistent networking between distributed locations.
3. **Kubernetes** clusters in each geolocation manage services and workloads.
4. **Linkerd** provides service mesh for communication and service discovery across locations.
5. **MinIO** handles federated object storage, ensuring data consistency and synchronization upon reconnection.

## Logo

![Amoebius Logo](icon.png)

## Getting Started

To deploy Amoebius across multiple geolocations:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/amoebius.git
   ```

2. Configure your geolocations and cloud environments in the Terraform files.

3. Use Linkerd to ensure smooth service failover and communication between geolocations.

4. Set up MinIO for federated storage and synchronization.

## Contributing

We welcome contributions to improve Amoebius. Please open issues or submit pull requests on GitHub.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
