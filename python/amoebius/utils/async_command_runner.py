import asyncio
import socket
from contextlib import asynccontextmanager
from typing import Dict, List, Optional


class CommandError(Exception):
    """Custom exception for command execution errors.

    Attributes:
        message: A description of the error.
        return_code: The return code of the failed command, if applicable.
    """
    def __init__(self, message: str, return_code: Optional[int] = None) -> None:
        super().__init__(message)
        self.return_code = return_code


async def run_command(
    command: List[str],
    sensitive: bool = True,
    env: Optional[Dict[str, str]] = None,
    cwd: Optional[str] = None,
    input_data: Optional[str] = None,
    retries: int = 3,
    retry_delay: int = 1,
) -> str:
    """Run a shell command asynchronously and return its stdout output.

    Args:
        command: The command and arguments to execute.
        sensitive: If True, command details and output are hidden in errors.
        env: Optional environment variables to set for the process.
        cwd: Optional working directory for the process.
        input_data: Optional string to pass to the process's stdin.
        retries: Number of times to retry the command if it fails.
        retry_delay: Delay in seconds between retries.

    Returns:
        The stdout output of the command as a string.

    Raises:
        CommandError: If the command fails after the given number of retries.
    """
    try:
        process = await asyncio.create_subprocess_exec(
            *command,
            stdin=asyncio.subprocess.PIPE if input_data else None,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
            cwd=cwd,
        )
        stdout_bytes, stderr_bytes = await process.communicate(
            input=input_data.encode() if input_data else None
        )
        if process.returncode != 0:
            raise CommandError(
                (
                    f"Command failed with return code {process.returncode}"
                    + (
                        f"\nCommand: {' '.join(command)}"
                        f"\nStdout: {stdout_bytes.decode()}"
                        f"\nStderr: {stderr_bytes.decode()}"
                        if not sensitive else ""
                    )
                ),
                process.returncode,
            )
        return stdout_bytes.decode().strip()
    except CommandError as e:
        if retries > 0:
            await asyncio.sleep(retry_delay)
            return await run_command(command, sensitive, env, cwd, input_data, retries - 1, retry_delay)
        else:
            raise e


async def is_port_forward_active(local_port: int, retries: int = 5, delay: int = 1) -> bool:
    """Check if the locally forwarded port is reachable.

    Tries to connect to localhost:<local_port> multiple times.

    Args:
        local_port: The local port to test connectivity on.
        retries: Number of connection attempts.
        delay: Delay in seconds between attempts.

    Returns:
        True if the port becomes reachable within the given attempts, False otherwise.
    """
    for attempt in range(retries):
        try:
            with socket.create_connection(("localhost", local_port), timeout=1):
                return True
        except (socket.timeout, ConnectionRefusedError):
            if attempt < retries - 1:
                await asyncio.sleep(delay)
    return False


@asynccontextmanager
async def ssh_kubectl_port_forward(
    ssh_host: str,
    ssh_user: str,
    ssh_key: str,
    service_name: str,
    namespace: str,
    local_port: int,
    service_port: int,
) -> None:
    """Context manager to forward a Kubernetes ClusterIP service port over SSH using kubectl.

    This sets up an SSH tunnel to a remote host, which runs `kubectl port-forward`
    to forward a service port. The chain looks like this:

    local:local_port → ssh tunnel → remote:local_port → kubectl port-forward → service:service_port

    Args:
        ssh_host: The hostname or IP of the remote machine.
        ssh_user: The SSH username for connecting to the remote machine.
        ssh_key: Path to the SSH private key file.
        service_name: Name of the Kubernetes service to forward.
        namespace: Namespace of the Kubernetes service.
        local_port: The local port to forward.
        service_port: The service port to forward on the Kubernetes cluster.

    Yields:
        None, but keeps the tunnel active while in the context.

    Raises:
        CommandError: If the port-forward setup fails or does not become active.
    """
    # SSH command explanation:
    # -i ssh_key: Use the given private key for authentication.
    # -L {local_port}:localhost:{local_port}: Forward local_port on local machine
    #   to local_port on the remote machine.
    # After establishing the SSH tunnel, we run `kubectl port-forward svc/service_name local_port:service_port -n namespace`
    # on the remote machine to forward the service port to the remote machine's localhost.
    ssh_command = [
        "ssh",
        "-i",
        ssh_key,
        "-L",
        f"{local_port}:localhost:{local_port}",
        "-o",
        "StrictHostKeyChecking=no",
        f"{ssh_user}@{ssh_host}",
        "kubectl",
        "port-forward",
        f"svc/{service_name}",
        f"{local_port}:{service_port}",
        "-n",
        namespace,
    ]

    process = await asyncio.create_subprocess_exec(
        *ssh_command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    try:
        # Test if the port forward is active.
        # If it's not active after a few attempts, we assume it failed.
        if not await is_port_forward_active(local_port):
            raise CommandError(f"Port forward to localhost:{local_port} could not be established")

        yield
    finally:
        # Terminate the SSH process to close the port forward when done.
        process.terminate()
        await process.wait()


async def run_command_with_port_forward() -> None:
    """Example function showing how to run a command against a service forwarded over SSH and kubectl."""
    ssh_host = "worker-node-ip"
    ssh_user = "your-ssh-username"
    ssh_key = "/path/to/private/key"

    service_name = "your-service-name"
    namespace = "default"
    local_port = 8080
    service_port = 80  # Change to the actual port of your service

    # Set up the ephemeral port forward context
    async with ssh_kubectl_port_forward(ssh_host, ssh_user, ssh_key, service_name, namespace, local_port, service_port):
        # Now we can access the service at localhost:local_port
        output = await run_command(["curl", f"http://localhost:{local_port}"], sensitive=False)
        print(f"Command output: {output}")


if __name__ == "__main__":
    asyncio.run(run_command_with_port_forward())
