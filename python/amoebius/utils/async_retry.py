import asyncio
import logging
from typing_extensions import ParamSpec, TypeVar
from typing import Awaitable, Callable

P = ParamSpec("P")
R = TypeVar("R")

logger = logging.getLogger(__name__)


def async_retry(
    retries: int = 3,
    delay: float = 1.0,
    noisy: bool = False,
) -> Callable[[Callable[P, Awaitable[R]]], Callable[P, Awaitable[R]]]:
    """
    Decorator to retry an async function up to 'retries' times,
    sleeping 'delay' seconds between attempts.

    If 'noisy' is True, logs each failure and the final error.

    Note: 'retries' is the total number of attempts allowed, not the
    number of failures. So if retries=3, it will attempt up to 3 times.
    """

    def decorator(func: Callable[P, Awaitable[R]]) -> Callable[P, Awaitable[R]]:
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            async def attempt(remaining: int, attempt_number: int) -> R:
                try:
                    return await func(*args, **kwargs)
                except Exception as exc:
                    if noisy:
                        logger.warning(
                            "Attempt %d/%d for function %r with args=%s, kwargs=%s failed. Error: %s",
                            attempt_number,
                            retries,
                            func.__qualname__,
                            args,
                            kwargs,
                            exc,
                        )

                    # Only retry if we still have > 1 remaining attempts.
                    # (remaining corresponds to total attempts left, including this one)
                    if remaining > 1:
                        await asyncio.sleep(delay)
                        return await attempt(remaining - 1, attempt_number + 1)

                    # No more attempts left, so log final error (if noisy) and raise
                    if noisy:
                        logger.error(
                            "All %d attempts failed for function %r with args=%s, kwargs=%s",
                            retries,
                            func.__qualname__,
                            args,
                            kwargs,
                        )
                    raise

            # Kick off the first attempt, with 'remaining' = total attempts
            return await attempt(retries, 1)

        return wrapper

    return decorator
