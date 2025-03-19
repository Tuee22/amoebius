"""
amoebius/utils/ephemeral_file.py

Provides a generalized async context manager for ephemeral files in `/dev/shm` that
supports both:

1) **Single-file mode**: Create one ephemeral file path, yield that path (as a string).
2) **Symlink mode**: Create ephemeral files for each entry in `symlink_map`, symlink
   them to real paths, yield a dict of ephemeral file paths keyed by ephemeral filename.

We use:
 - A dict comprehension for building ephemeral_paths in symlink mode (since that's
   actually constructing a final dictionary).
 - For-loops for side effects (removing files, creating symlinks).
This avoids confusing or hacky comprehensions that return None or bool.
"""

import os
import tempfile
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Dict, Optional, Union


@asynccontextmanager
async def ephemeral_manager(
    *,
    single_file_name: Optional[str] = None,
    symlink_map: Optional[Dict[str, str]] = None,
    prefix: str = "ephemeral-",
    parent_dir: str = "/dev/shm",
) -> AsyncGenerator[Union[str, Dict[str, str]], None]:
    """
    A generalized async context manager for ephemeral usage in `/dev/shm`.

    Two modes:

    1) **Single-file mode**:
       - If `single_file_name` is set (and `symlink_map` is None),
         we create one ephemeral directory and yield one file path.
       - Yields a single `str` path.

    2) **Symlink mode**:
       - If `symlink_map` is set (and `single_file_name` is None),
         we create ephemeral files for each key in symlink_map, then symlink
         them to the specified real path.
       - Yields a `dict` of ephemeral filename -> ephemeral path (in /dev/shm).

    Everything is cleaned up on exit: symlinks removed, ephemeral files removed,
    ephemeral directory removed.

    Args:
        single_file_name: The ephemeral filename if you only want one file, no symlinks.
        symlink_map: A dict of ephemeral_filename -> real_path_for_symlink if you want
                     multiple ephemeral files symlinked to real paths.
        prefix: Prefix for the ephemeral directory name.
        parent_dir: The directory to place the ephemeral directory, default `/dev/shm`.

    Yields:
        str or Dict[str,str], depending on the mode.

    Raises:
        ValueError: If both single_file_name and symlink_map are provided, or neither is.
    """
    # Validate usage
    if (single_file_name is not None and symlink_map is not None) or (
        single_file_name is None and symlink_map is None
    ):
        raise ValueError(
            "Must provide exactly one of 'single_file_name' or 'symlink_map'."
        )

    ephemeral_dir = tempfile.mkdtemp(dir=parent_dir, prefix=prefix)

    try:
        if single_file_name is not None:
            # SINGLE-FILE MODE
            ephemeral_path = os.path.join(ephemeral_dir, single_file_name)
            yield ephemeral_path

        else:
            # SYMLINK MODE
            assert symlink_map is not None, "symlink_map unexpectedly None"

            # Build ephemeral_paths with a dict comprehension
            ephemeral_paths = {
                ephemeral_name: os.path.join(ephemeral_dir, ephemeral_name)
                for ephemeral_name in symlink_map
            }

            # Create symlinks via for-loops for clarity
            for ephemeral_name, symlink_target in symlink_map.items():
                # If the symlink target already exists, remove it
                if os.path.lexists(symlink_target):
                    os.remove(symlink_target)

                # Create a symlink from ephemeral_paths[ephemeral_name] -> symlink_target
                os.symlink(ephemeral_paths[ephemeral_name], symlink_target)

            yield ephemeral_paths

    finally:
        # Remove symlinks (if symlink_map is in use)
        if symlink_map is not None:
            for symlink_target in symlink_map.values():
                if os.path.lexists(symlink_target):
                    os.remove(symlink_target)

        # Remove ephemeral files, then remove ephemeral_dir
        if os.path.isdir(ephemeral_dir):
            for item in os.listdir(ephemeral_dir):
                item_path = os.path.join(ephemeral_dir, item)
                if os.path.isfile(item_path) or os.path.islink(item_path):
                    os.remove(item_path)
            os.rmdir(ephemeral_dir)
