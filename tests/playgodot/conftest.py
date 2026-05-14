from pathlib import Path
import os

import pytest

pytest.importorskip("playgodot")

PROJECT_ROOT = Path(__file__).resolve().parents[2]
GODOT_PATH = os.environ.get("PLAYGODOT_GODOT_PATH")


@pytest.fixture(scope="session")
def project_root() -> Path:
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def automation_godot_path() -> str:
    if not GODOT_PATH:
        pytest.skip("PLAYGODOT_GODOT_PATH is not set")
    return GODOT_PATH
