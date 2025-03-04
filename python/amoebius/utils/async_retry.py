import asyncio
import logging
from typing_extensions import ParamSpec, TypeVar
from typing import Awaitable, Callable

P = ParamSpec("P")
R = TypeVar("R")

logger = logging.getLogger(__name__)


def async_retry(
    retries: int = 3, delay: float = 1.0
) -> Callable[[Callable[P, Awaitable[R]]], Callable[P, Awaitable[R]]]:
    """
    Decorator to retry an async function up to 'retries' times,
    sleeping 'delay' seconds between attempts.

    Now made "noisy" by default: logs each failure and final error.
    """

    def decorator(func: Callable[P, Awaitable[R]]) -> Callable[P, Awaitable[R]]:
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            async def attempt(remaining: int, attempt_number: int) -> R:
                try:
                    return await func(*args, **kwargs)
                except Exception as exc:
                    # "Noisy" logging of context:
                    logger.warning(
                        "Attempt %d/%d for function %r with args=%s, kwargs=%s failed. Error: %s",
                        attempt_number,
                        retries,
                        func.__qualname__,
                        args,
                        kwargs,
                        exc,
                    )
                    if remaining > 0:
                        await asyncio.sleep(delay)
                        return await attempt(remaining - 1, attempt_number + 1)

                    # Log final failure after exhausting all retries
                    logger.error(
                        "All %d retries failed for function %r with args=%s, kwargs=%s",
                        retries,
                        func.__qualname__,
                        args,
                        kwargs,
                    )
                    raise

            return await attempt(retries, 1)

        return wrapper

    return decorator
