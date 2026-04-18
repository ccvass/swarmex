from typing import Any


def _unwrap(obj):
    """If obj is an Attr whose value is a dict, return the dict. Otherwise return obj as-is."""
    # Import here to avoid circular imports
    from authentik.lib.config import Attr
    if isinstance(obj, Attr) and isinstance(obj.value, dict):
        return obj.value
    return obj


def get_path_from_dict(root: dict, path: str, sep=".", default=None) -> Any:
    """Recursively walk through `root`, checking each part of `path` separated by `sep`.
    If at any point a dict does not exist, return default"""
    for comp in path.split(sep):
        root = _unwrap(root)
        if isinstance(root, dict) and comp in root:
            root = root.get(comp)
        else:
            return default
    return root


def set_path_in_dict(root: dict, path: str, value: Any, sep="."):
    """Recursively walk through `root`, checking each part of `path` separated by `sep`
    and setting the last value to `value`"""
    path_parts = path.split(sep)
    for comp in path_parts[:-1]:
        root = _unwrap(root)
        if comp not in root:
            root[comp] = {}
        root = _unwrap(root.get(comp, {}))
    root = _unwrap(root)
    root[path_parts[-1]] = value
