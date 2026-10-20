"""Index of HD art modules. Adding an HD hero = add a module in heroes/ and list it here."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "heroes"))
import hexer  # noqa: E402
import ranger  # noqa: E402
import tinker  # noqa: E402
import warden  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "enemies"))
import golem  # noqa: E402

# Art pixels per world unit for all HD assets (a 16-unit floor tile = 64 px).
DENSITY = 4

HEROES = {
    "ranger": ranger,
    "warden": warden,
    "hexer": hexer,
    "tinker": tinker,
}

ENEMIES = {
    "golem": golem,
}
