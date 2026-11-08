"""forge: game-asset operations for Blender, importable in the live session and in `blender -b`.

Live session: import sys; sys.path.insert(0, "<plugin root>/blender_lib"); import forge
Every public function returns a dict with "ok"; refusals raise forge.util.ForgeError with a `stage`."""
from .util import ForgeError

__all__ = ["ForgeError"]
