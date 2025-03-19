"""
amoebius/utils/ephemeral_file.py

Provides a generic asynchronous context manager for ephemeral files in `/dev/shm`
that are symlinked to user-specified paths on the filesystem. When the context
exits, both the symlinks and the underlying ephemeral files are cleaned up.

We use regular for-loops for side effects (removing symlinks, ephemeral files).
"""

import os
import tempfile
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Dict


def _create_symlink(
    ephemeral_dir: str, ephemeral_name: str, symlink_target: str
) -> str:
    """
    Create or overwrite a symlink at `symlink_target` pointing to the ephemeral path,
    returning the ephemeral path for dictionary population.
    """
    ephemeral_path = os.path.join(ephemeral_dir, ephemeral_name)
    if os.path.lexists(symlink_target):
        os.remove(symlink_target)
    os.symlink(ephemeral_path, symlink_target)
    return ephemeral_path


@asynccontextmanager
async def ephemeral_symlinks(
    symlink_map: Dict[str, str],
    prefix: str = "ephemeral-",
    parent_dir: str = "/dev/shm",
) -> AsyncGenerator[Dict[str, str], None]:
    """
    Create ephemeral files in /dev/shm, symlink each ephemeral file to a corresponding
    target path, and clean up both file(s) and symlink(s) on exit.

    The keys of `symlink_map` are ephemeral filenames (created inside the ephemeral dir),
    and the values are absolute paths to which the ephemeral file will be symlinked.

    Args:
        symlink_map (Dict[str, str]):
            e.g. {"myfile.txt": "/path/on/disk/myfile.txt"} means
            "/dev/shm/<temp-dir>/myfile.txt" is symlinked at "/path/on/disk/myfile.txt".
        prefix (str):
            A prefix for the temporary directory name created in /dev/shm.
        parent_dir (str):
            Directory in which to create the temporary directory (default `/dev/shm`).

    Yields:
        Dict[str, str]:
            A dict with the same keys as `symlink_map`, but whose values are the absolute
            ephemeral file paths in `/dev/shm`. You can read/write to these ephemeral
            files while they're symlinked to your desired location.

    Raises:
        OSError: If file operations fail during symlink creation or removal.
    """
    ephemeral_dir = tempfile.mkdtemp(dir=parent_dir, prefix=prefix)

    # Build ephemeral_paths. We can still use a dict comprehension for convenience:
    ephemeral_paths: Dict[str, str] = {
        ephemeral_name: _create_symlink(ephemeral_dir, ephemeral_name, symlink_target)
        for ephemeral_name, symlink_target in symlink_map.items()
    }

    try:
        yield ephemeral_paths
    finally:
        # Remove symlinks:
        for symlink_target in symlink_map.values():
            if os.path.lexists(symlink_target):
                os.remove(symlink_target)

        # Remove ephemeral files and the ephemeral_dir:
        if os.path.isdir(ephemeral_dir):
            for item in os.listdir(ephemeral_dir):
                item_path = os.path.join(ephemeral_dir, item)
                if os.path.isfile(item_path) or os.path.islink(item_path):
                    os.remove(item_path)
            os.rmdir(ephemeral_dir)
