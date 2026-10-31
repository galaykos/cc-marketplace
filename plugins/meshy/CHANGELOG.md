# Changelog — meshy

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-30

- New plugin. `meshy-generation` skill: the API's paid-task rules (reconcile an unknown create, never resubmit; a running task cannot be cancelled; the two kinds of `429`), the 3-day file and signed-URL expiry, Smart Topology and remesh polycount ranges, rigging and animation limits, the plan-tier licence from Meshy's Terms of Use, and the meshy-cli 0.7 exit codes — each re-checked against docs.meshy.ai on 2026-10-30.
- `scripts/inspect_glb.py`: stdlib Python 3 check of `.glb`/`.gltf` files — drawn triangles, PNG/JPEG image sizes, required extensions, world extents in metres — exiting 1 on `--max-tris`, `--max-texture`, a required extension not passed to `--allow-ext`, or a missing external file, and 2 on a file that is not readable glTF 2.0.
