# C++, automation and Behavior Tree notes — UE 5.x

Carried from the upstream source; not re-read against Epic's docs on 2026-10-26.

## Run automation tests headless

```bash
UnrealEditor-Cmd <Project>.uproject -ExecCmds="Automation RunTest MyGame;Quit"
```

`RunTest` takes a full test name, a dotted prefix (`MyGame.Inventory`) or `Group:<name>`. Use
`UnrealEditor-Cmd.exe` on Windows.

## Holding UObjects from a plain C++ class

`UPROPERTY` only works inside reflected types. A plain C++ class (no `UCLASS`/`USTRUCT`) that
must keep a `UObject` alive has two options:

- `TStrongObjectPtr<T>`, which holds a strong reference for as long as the pointer lives;
- derive from `FGCObject` and override both `AddReferencedObjects` (report each object) and
  `GetReferencerName`.

A raw `UObject*` held anywhere else is invisible to the garbage collector and can dangle.
Reference without keeping alive with `TWeakObjectPtr<T>`, and check it before each use.

## Behavior Trees

- If the project already has StateTree assets, or the AI is a set of modes with explicit
  transitions, ask before adding a Behavior Tree next to it. Behavior Trees are not deprecated;
  where `BT_`/`BB_` assets exist, keep using them.
- Task nodes are not instanced by default: one node object serves every AI running the tree.
  Never keep per-run state (timer handles, counters) in member variables. Put it in node
  memory: override `GetInstanceMemorySize`, construct and destroy the block with
  `InitializeNodeMemory<T>` / `CleanupNodeMemory<T>` in `InitializeMemory`/`CleanupMemory`,
  and read it with `CastInstanceNodeMemory<T>`. Member `UPROPERTY`s of a non-instanced node are
  read-only settings.
- A latent task returns `EBTNodeResult::InProgress` and must end with `FinishLatentTask`. Its
  `AbortTask` must cancel whatever would call `FinishLatentTask` later, such as a pending timer.
