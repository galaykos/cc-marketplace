"""Engine-preset naming patterns such as '{name}_LOD{n}' or 'UCX_{name}_{nn}': one rule for every module.
{name} is any non-empty text, {n} one or more digits, {nn} two or more digits (written zero-padded to two)."""
import re

import bpy

from .util import ForgeError

PLACEHOLDER = re.compile(r"\{(name|nn|n)\}")
GROUPS = {"name": r"(?P<name>.+)", "n": r"(?P<n>\d+)", "nn": r"(?P<nn>\d{2,})"}
COLLISION_TOKEN = re.compile(r"(?i)(^|[_\-.])((ucx|ubx|usp|ucp)|(conv)?col(lider|lision|only)?)(?=$|[_\-.\d])")


def pattern_regex(pattern, **fixed):
    """Compiled regex for a naming pattern, to use with fullmatch. A placeholder given in `fixed` (name=, n=, nn=)
    matches that literal value; the others become the named groups name, n and nn."""
    parts, pos = [], 0
    for m in PLACEHOLDER.finditer(pattern):
        key = m[1]
        parts += [re.escape(pattern[pos:m.start()]), re.escape(str(fixed[key])) if key in fixed else GROUPS[key]]
        pos = m.end()
    parts.append(re.escape(pattern[pos:]))
    return re.compile("".join(parts))


def format_name(pattern, name, number=None):
    """The pattern filled with `name`, {n} with `number` and {nn} with `number` zero-padded to two digits. Returns a
    string; raises ForgeError when the pattern has a number placeholder and `number` is None."""
    def fill(m):
        if m[1] == "name":
            return name
        if number is None:
            raise ForgeError(f"naming pattern {pattern!r} needs a number for {{{m[1]}}}")
        return f"{number:02d}" if m[1] == "nn" else str(number)
    return PLACEHOLDER.sub(fill, pattern)


def split_lod(obj_name, lod_pattern):
    """(base name, LOD level) when obj_name follows the LOD pattern, else (obj_name, None)."""
    match = pattern_regex(lod_pattern).fullmatch(obj_name) if lod_pattern else None
    if match is None or not {"name", "n"} <= set(match.groupdict()):
        return obj_name, None
    return match["name"], int(match["n"])


def lod0_base(obj_name, lod_pattern):
    """The base name of a LOD0 or unsuffixed mesh name; raises ForgeError for LOD1 and up."""
    base, level = split_lod(obj_name, lod_pattern)
    if level:
        raise ForgeError(f"{obj_name} is LOD{level}; build the chain from LOD0")
    return base


def lod_objects(base, lod_pattern):
    """{level: object} for every object named as a LOD of `base` under the LOD pattern."""
    regex = pattern_regex(lod_pattern, name=base)
    found = {}
    for o in bpy.data.objects:
        match = regex.fullmatch(o.name)
        if match:
            found[int(match["n"])] = o
    return found


def collision_objects(render_name, patterns):
    """Objects, sorted by name, whose name follows one of the collision `patterns` filled with exactly
    `render_name`: the hulls an engine pairs with that mesh."""
    regexes = [pattern_regex(p, name=render_name) for p in set(patterns)]
    return sorted((o for o in bpy.data.objects if any(r.fullmatch(o.name) for r in regexes)), key=lambda o: o.name)
