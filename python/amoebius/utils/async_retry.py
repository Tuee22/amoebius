from __future__ import annotations

import asyncio
import functools
from typing import (
    Any,
    Callable,
    TypeVar,
    Awaitable,
    ParamSpec,
)

_P = ParamSpec("_P")
_R = TypeVar("_R")


def async_retry(
    retries: int = 30, delay: float = 1.0
) -> Callable[[Callable[_P, Awaitable[_R]]], Callable[_P, Awaitable[_R]]]:
    """
    An async decorator that uses recursion to retry the wrapped coroutine on exception.

    :param retries: Maximum number of retry attempts. Default is 30.
    :param delay: Delay (in seconds) between retries. Default is 1.
    :return: A decorator that wraps an async function with retry logic.

    Example usage

    @async_retry_recursively(retries=3, delay=1.0)
    async def my_unstable_function() -> str:
        print("Attempting unstable operation...")
        raise ValueError("Something went wrong!")
    """

    def decorator(coro: Callable[_P, Awaitable[_R]]) -> Callable[_P, Awaitable[_R]]:
        @functools.wraps(coro)
        async def wrapper(*args: _P.args, **kwargs: _P.kwargs) -> _R:
            async def attempt(remaining: int) -> _R:
                try:
                    return await coro(*args, **kwargs)
                except Exception:
                    if remaining > 0:
                        await asyncio.sleep(delay)
                        return await attempt(remaining - 1)
                    else:
                        raise

            return await attempt(retries)

        return wrapper

    return decorator
