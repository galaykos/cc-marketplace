---
name: pipeline
description: Use when making or changing a game asset in Blender — prop, character, creature, rock, modular piece — for Unity, Unreal, Godot or glTF — the project's asset-forge.json (engine, platform tiers, style, camera, budgets), the step order from brief to export, which steps run live and which headless on a snapshot, and how to import the forge library in the live session.
disable-model-invocation: true
---

**Status: skeleton.** The forge server exposes only `env_check` (`mcp__plugin_asset-forge_forge__env_check`); the forge library, review renders and validator are not built yet. Until they are, say so to the user instead of improvising this skill from memory.

Neighbours: `blender:blender-best-practices` for bpy API breaks and export rules, `gamedev:asset-pipeline` for a concept image through Meshy to an engine.
