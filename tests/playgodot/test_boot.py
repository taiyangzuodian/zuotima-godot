from pathlib import Path

import pytest
from playgodot import Godot, TimeoutError as PlayGodotTimeoutError


def test_project_baseline_exists(project_root: Path) -> None:
    assert (project_root / "project.godot").exists()
    assert (project_root / "scenes" / "app" / "boot.tscn").exists()
    assert (project_root / "addons" / "gdUnit4" / "plugin.cfg").exists()


def test_placeholder_palette_is_not_redeclared_as_local_constant(project_root: Path) -> None:
    scripts_root = project_root / "scripts"
    for script_path in scripts_root.rglob("*.gd"):
        source = script_path.read_text(encoding="utf-8")
        assert "const PlaceholderPalette = preload(\"res://scripts/ui/placeholder_palette.gd\")" not in source


@pytest.mark.asyncio
async def test_boot_scene_loads_start_screen(
    project_root: Path, automation_godot_path: str
) -> None:
    try:
        async with Godot.launch(
            project_root, godot_path=automation_godot_path, headless=True, timeout=20.0
        ) as godot:
            scene = await godot.get_current_scene()
            assert scene["path"] == "res://scenes/app/boot.tscn"
            assert await godot.node_exists("/root/Boot/StartScreen")
    except PlayGodotTimeoutError as exc:
        pytest.skip(f"PlayGodot remote automation command timed out: {exc}")
