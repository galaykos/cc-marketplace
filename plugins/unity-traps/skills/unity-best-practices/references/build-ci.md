# Builds, batch-mode CI and save paths — Unity 6

> Last verified: 2026-10-26 — https://docs.unity3d.com/6000.3/Documentation/Manual/EditorCommandLineArguments.html

Re-read against Unity's docs on the stamp date: the batch-mode target switch, `-buildTarget`,
`-activeBuildProfile` and `-build`, the exit-code paths, build-profile scene lists and
`Application.persistentDataPath`. Carried from the upstream source without a re-read: the
define-symbol, `Debug.LogError`, `-version` and Addressables items.

## Pick the platform on the command line

- `EditorUserBuildSettings.SwitchActiveBuildTarget` is not available in batch mode. A target
  switch needs a script recompile, which cannot happen while `-executeMethod` code runs.
- Launch with `-buildTarget <name>` instead (`win64`, `osxuniversal`, `linux64`, `android`,
  `ios`, `webgl`). The Editor starts on that platform and compiles with its `UNITY_*` defines.
- A scripted `BuildPipeline.BuildPlayer` for a target other than the active one keeps the active
  platform's defines; define changes apply only after a domain reload. Run one platform per
  Editor launch.

## Build Profiles (Unity 6)

- A build profile can carry its own Scene List (Add Settings → Scene List, seeded from the global
  list at that moment). From then on, building that profile ignores scenes added to the global
  list. Edit the profile's list.
- Build a profile from code with
  `BuildPipeline.BuildPlayer(new BuildPlayerWithProfileOptions { buildProfile = profile, locationPathName = path })`
  (`UnityEditor.Build.Profile.BuildProfile`), so the profile's scenes and settings are used.
- Build one with no script:
  `-activeBuildProfile "<path relative to the project root>" -build "<output path>"`.

## Make CI fail when the build fails

- In batch mode an `-executeMethod` method fails the process (exit 1) only by throwing, or by
  `EditorApplication.Exit(<non-zero>)`. A `Debug.LogError` does not change the exit code.
- `BuildPipeline.BuildPlayer` returns normally from a failed build. Check
  `report.summary.result == BuildResult.Succeeded`.
- `Environment.GetCommandLineArgs()` includes Unity's own flags. Never name a custom flag after
  one of them: `-buildTarget`, `-build`, `-quit`, `-version` (the last prints the Editor version
  and exits without building).

```csharp
// Unity -batchmode -nographics -projectPath . -buildTarget win64 -executeMethod CIBuild.Run -logFile -
public static class CIBuild
{
    public static void Run()
    {
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray(),
            locationPathName = "Builds/Win/Game.exe",
            target = EditorUserBuildSettings.activeBuildTarget,   // set by -buildTarget at launch
            options = BuildOptions.None,
        });
        EditorApplication.Exit(report.summary.result == BuildResult.Succeeded ? 0 : 1);
    }
}
```

## Addressables in CI

When `com.unity.addressables` is installed, build the content explicitly before the player
build: call `AddressableAssetSettings.BuildPlayerContent(out var result)` and fail on a
non-empty `result.Error`. The "Build Addressables on Player Build" setting, left at "Use global
Settings", defers to each machine's Editor Preferences, so a clean runner may skip the content
build.

## Save paths

- `Application.persistentDataPath` is an empty string on tvOS, which it does not support. Use
  another store there.
- On desktop the path contains the Company Name and Product Name from Player Settings. Renaming
  either after release moves the folder, and existing saves stop being found. Migrate them, or
  never rename.
- On WebGL the path is IndexedDB, keyed by a hash of the URL of the page's directory. Moving the
  build to another directory or host starts the player with empty saves.
