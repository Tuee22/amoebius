"""
amoebius/models/validator.py
"""



from typing import Any, Type, TypeVar
from pydantic import ValidationError, TypeAdapter

T = TypeVar("T")


def validate_type(obj: Any, expected_type: Type[T]) -> T:
    """
    Validates that the given object conforms to the expected type using Pydantic.

    Args:
        obj (Any): The object to validate.
        expected_type (Type[T]): The type to validate against.

    Returns:
        T: The validated object cast to the expected type.

    Raises:
        ValueError: If validation fails.
    """
    try:
        adapter = TypeAdapter(expected_type)
        return adapter.validate_python(obj)
    except ValidationError as e:
        # Optionally, you can customize the error message further
        raise ValueError(f"Validation failed for type {expected_type}: {e}") from e
