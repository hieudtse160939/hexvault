"""Index of HD art modules. Adding an HD hero = add a module in heroes/ and list it here."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "heroes"))
import artillerist  # noqa: E402
import assassin  # noqa: E402
import cryomancer  # noqa: E402
import duelist  # noqa: E402
import hexer  # noqa: E402
import necromancer  # noqa: E402
import paladin  # noqa: E402
import pyromancer  # noqa: E402
import stormcaller  # noqa: E402
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
    "duelist": duelist,
    "pyromancer": pyromancer,
    "cryomancer": cryomancer,
    "stormcaller": stormcaller,
    "necromancer": necromancer,
    "assassin": assassin,
    "paladin": paladin,
    "artillerist": artillerist,
}

ENEMIES = {
    "golem": golem,
}
