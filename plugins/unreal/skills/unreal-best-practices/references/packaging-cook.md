# Packaging and cooking — UE 5.8

> Last verified: 2026-10-26 — https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-8-release-notes

Re-read against Epic's docs on the stamp date: the Zen items (the 5.8 release notes and
https://dev.epicgames.com/documentation/en-us/unreal-engine/using-zen-storage-server-as-cooked-output-store-for-unreal-engine)
and the SDK table. Carried from the upstream source without a re-read: the console-build,
DataValidation and Shipping items, and the BuildCookRun example.

## Zen Server is the cooked output store by default

- Epic's 5.5 page said Zen was not the default cooked output store and that this was planned to
  change. The 5.8 release notes say it now is: "Zenserver as Cooked Output Store is now enabled
  by default."
- So after a successful 5.8 cook, `Saved/Cooked/<Platform>` holds only `ue.projectstore`, a
  small descriptor of where the cooked data is stored. It has no `.uasset`, `.uexp` or `.ubulk`
  files. That is not a failed cook.
- Staging still writes the container files (`.pak`, plus `.utoc`/`.ucas` with Use Io Store, the
  default) to the staging directory. Ship that directory, never `Saved/Cooked`.
- To opt out, turn off Project Settings → Packaging → "Use Zenserver as cooked output store",
  or pass `-skipzenstore` to a single cook.
- On team and CI machines, keep zenserver alive between steps instead of starting and stopping
  it on each one. Make sure the build automation tolerates that long-running process.

  ```ini
  ; Config/DefaultEngine.ini
  [Zen.AutoLaunch]
  LimitProcessLifetime=false
  ```

## UE 5.8 toolchain minimums

| Tool | Minimum | Recommended / default |
|---|---|---|
| Visual Studio | 2022 v17.14 | 2026 |
| MSVC toolset | 14.38 | 14.50 |
| Windows SDK | 10.0.22621.0 | 10.0.26100.0 (default) |
| Xcode | 15.2 | 15.4 or newer |

A build that fails early on a fresh machine usually has a toolchain below these. Check the
release notes' platform SDK table for other targets. Console packaging needs a source-built
engine, not the launcher build.

## Before and after the cook

- Validate assets before cooking: `UnrealEditor-Cmd <Project>.uproject -run=DataValidation`
  (`UnrealEditor-Cmd.exe` on Windows). Fix every reported error first.
- Shipping strips the console and `UE_LOG`, so there is no `quit` console command. The game
  needs its own exit option, and a Shipping-only bug is debugged in the Test configuration.
- Verify by launching the packaged build, not by a cook that returned 0.

```bash
# Cook, build, stage, pak and archive a Shipping Win64 build (RunUAT.sh on macOS/Linux).
Engine/Build/BatchFiles/RunUAT.bat BuildCookRun -project="C:/Path/MyGame.uproject" -noP4 \
  -platform=Win64 -clientconfig=Shipping -build -cook -stage -pak -archive \
  -archivedirectory="C:/Builds/MyGame"
```
