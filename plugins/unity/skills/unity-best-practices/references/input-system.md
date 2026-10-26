# Input System — Unity 6

> Last verified: 2026-10-26 — https://docs.unity3d.com/Packages/com.unity.inputsystem@1.17/manual/PlayerInput.html

Read `com.unity.inputsystem` from `Packages/packages-lock.json` first. Project-wide actions
exist from 1.8; on an older package the second section does not apply. Everything in this file
was re-read against Unity's docs on the stamp date, except the `InvalidOperationException`
detail, which is carried from the upstream source.

## The legacy Input Manager is on its way out

- Unity's manual calls the Input Manager legacy and not recommended for new projects, and the
  6000.6 manual states it will be removed in a future version. Write new input code against the
  Input System package.
- Project Settings → Player → Active Input Handling chooses Input Manager (Old), Input System
  Package (New) or Both. Under New, a leftover `Input.GetAxis`/`Input.GetKey` call throws
  `InvalidOperationException`. Set Both while migrating, then port the calls.

## Project-wide actions enable every action map

- `InputSystem.actions` is the asset assigned in Project Settings → Input System Package (new
  projects ship `InputSystem_Actions.inputactions`). It starts enabled, and so do all of its
  maps, UI and gameplay together. A `PlayerInput` pointed at that asset gets the same, so
  gameplay actions fire while a menu is open.
- Fix it once, in `Start`:

  ```csharp
  InputSystem.actions.Disable();
  playerInput.currentActionMap?.Enable();
  ```

- With a `PlayerInput` in play, read its own `playerInput.actions`, never
  `InputSystem.actions`. The latter is the shared singleton, not the private copy that
  PlayerInput uses, so enabling or reading it acts on the wrong instance.
- Answers written for Input System 1.5 and earlier say PlayerInput enables only its Default Map.
  With project-wide actions that no longer holds.
- `FindAction` returns null: the name is wrong, or the asset you edited is not the one assigned
  in Project Settings. Reuse the assigned asset rather than adding a second one.

## UI after the switch

- `StandaloneInputModule` connects uGUI to the legacy Input Manager, not to your Input System
  actions. Replace it with `InputSystemUIInputModule`; the old module's Inspector offers a
  replace button.
- UI Toolkit on 2023.2 and later, which covers all of Unity 6, needs no UI input module
  component.
