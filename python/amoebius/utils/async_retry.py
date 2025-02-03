import asyncio
from typing_extensions import ParamSpec, TypeVar
from typing import Awaitable, Callable

P = ParamSpec("P")
R = TypeVar("R")


def async_retry(
    retries: int = 3, delay: float = 1.0
) -> Callable[[Callable[P, Awaitable[R]]], Callable[P, Awaitable[R]]]:
    """
    Decorator to retry an async function up to 'retries' times,
    sleeping 'delay' seconds between attempts.
    """

    def decorator(func: Callable[P, Awaitable[R]]) -> Callable[P, Awaitable[R]]:
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            async def attempt(remaining: int) -> R:
                try:
                    return await func(*args, **kwargs)
                except Exception:
                    if remaining > 0:
                        await asyncio.sleep(delay)
                        return await attempt(remaining - 1)
                    raise

            return await attempt(retries)

        return wrapper

    return decorator
