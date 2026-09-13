# Spiritbound — Godot 4

Portrait mobile migration of the Spiritbound Expo prototype. The original Expo project remains available as a gameplay reference.

## Requirements

- Godot 4.7.x Standard build (GDScript; .NET is not required)
- macOS and Xcode for iOS export
- Android Studio SDK/JDK 17 for Android export

## Run in the editor

1. Open Godot Project Manager.
2. Import this folder by selecting `project.godot`.
3. Press **F6/F5** or the Play button.
4. Keep the test window in portrait orientation. The design viewport is 390 × 844 and scales to other phone sizes.

## Automated test

```bash
/path/to/Godot --headless --path . --script res://tests/test_runner.gd
```

The suite verifies the 25-card finite deck, 50-stage campaign, equipment and rune definitions, action economy, multi-enemy Chain damage, card cycling, opening equipment effects, Mist Cloak, Phoenix Mail, and the save schema.

## Mobile testing

Install matching Godot export templates from **Editor → Manage Export Templates**. Add an Android or iOS preset under **Project → Export**. For iOS, set the bundle identifier and Apple Team ID, export an Xcode project, then build to the connected iPhone from Xcode.

The save file is stored at `user://spiritbound-save.json`. Delete it from the Godot user data directory to test a fresh profile.
