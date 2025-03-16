"""
amoebius/utils/async_retry.py

Provides a decorator to retry an async function multiple times upon failure.
"""

import asyncio
import logging
from typing import Any, Callable, Coroutine
from typing_extensions import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

logger = logging.getLogger(__name__)


def async_retry(
    retries: int = 3,
    delay: float = 1.0,
    noisy: bool = False,
) -> Callable[
    [Callable[P, Coroutine[Any, Any, R]]], Callable[P, Coroutine[Any, Any, R]]
]:
    """Decorates an async function to retry upon failure.

    The decorated function will be attempted up to `retries` times, with a delay
    of `delay` seconds between each attempt. If `noisy` is True, logs warnings on
    each failure and an error on the final failure.

    Args:
        retries (int, optional):
            Maximum number of total attempts (not just failures). Defaults to 3.
        delay (float, optional):
            Delay in seconds between attempts. Defaults to 1.0.
        noisy (bool, optional):
            If True, logs a warning on each failure and an error if all attempts fail.
            Defaults to False.

    Returns:
        Callable[[Callable[P, Coroutine[Any, Any, R]]], Callable[P, Coroutine[Any, Any, R]]]:
            A decorator that, when applied to an async function, returns a wrapped
            version that retries on exceptions.
    """

    def decorator(
        func: Callable[P, Coroutine[Any, Any, R]]
    ) -> Callable[P, Coroutine[Any, Any, R]]:
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            async def attempt(remaining: int, attempt_number: int) -> R:
                try:
                    return await func(*args, **kwargs)
                except Exception as exc:
                    if noisy:
                        logger.warning(
                            "Attempt %d/%d for function %r failed with args=%s, kwargs=%s. Error: %s",
                            attempt_number,
                            retries,
                            func.__qualname__,
                            args,
                            kwargs,
                            exc,
                        )
                    # If we have remaining attempts, retry
                    if remaining > 1:
                        await asyncio.sleep(delay)
                        return await attempt(remaining - 1, attempt_number + 1)

                    # Otherwise, no more attempts left
                    if noisy:
                        logger.error(
                            "All %d attempts failed for function %r with args=%s, kwargs=%s",
                            retries,
                            func.__qualname__,
                            args,
                            kwargs,
                        )
                    raise

            return await attempt(retries, 1)

        return wrapper

    return decorator
