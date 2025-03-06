"""
amoebius/models/validator.py

Defines a utility function for validating Python objects against
a pydantic-based type using TypeAdapter.
"""

from typing import Any, Type, TypeVar
from pydantic import ValidationError, TypeAdapter

T = TypeVar("T")


def validate_type(obj: Any, expected_type: Type[T]) -> T:
    """
    Validates that a given Python object conforms to the expected pydantic-based type.

    Args:
        obj (Any): The object to validate.
        expected_type (Type[T]): The type (pydantic or otherwise) to validate against.

    Returns:
        T: The validated object, cast to the expected type.

    Raises:
        ValueError: If validation fails.
    """
    try:
        adapter = TypeAdapter(expected_type)
        return adapter.validate_python(obj)
    except ValidationError as e:
        raise ValueError(f"Validation failed for type {expected_type}: {e}") from e
