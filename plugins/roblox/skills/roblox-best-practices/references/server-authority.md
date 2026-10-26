# Server Authority: what changes when a place opts in

> Last verified: 2026-10-26 — https://create.roblox.com/docs/projects/server-authority

Server Authority reached full release in July 2026
(https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993).
Answers from before then say Roblox has no built-in prediction and tell you to build
client prediction yourself over network ownership. In a place with
`Workspace.AuthorityMode = Server` that advice is wrong: the engine predicts, rolls back
and resimulates, and a hand-built scheme fights it.

## Check the mode first

- Read `Workspace.AuthorityMode`. Only `Server` turns this on.
- Setting it switches five other settings automatically: next-generation replication, the
  Input Action System for player scripts, deferred signal behaviour, fixed-step simulation
  and instance streaming (`Workspace.StreamingEnabled` is required). A place that was not
  streaming before now is, so client code that indexes workspace objects directly must
  tolerate their absence.
- Switching an existing place is a project-wide migration. Never do it as part of another
  task; report it as an option.

## Rules inside a Server Authority place

- **Simulation code runs in `RunService:BindToSimulation()` callbacks**, in a ModuleScript
  required by both a server `Script` and a client `LocalScript`, so both sides run the same
  steps. Inside those callbacks, only properties and methods labelled *Simulation Access*
  in the API reference are allowed.
- **Time comes from `time()`**, which is synchronized and rewinds during resimulation. Do
  not use `os.clock()` (an arbitrary local baseline), `tick()` or `os.time()` for anything
  that affects the simulation.
- **Synchronized custom state lives in Attributes** on predicted instances, written only
  inside bound simulation functions. Only the first **64** attributes on an instance
  replicate; the rest stay local.
- **Drive predicted forces and constraints from `BindToSimulation`** on both sides, not from
  `Heartbeat` or client-only scripts. Physics scripts written for client network ownership
  need adapting when a place switches modes.
- **Input that affects the simulation goes through `InputAction`s**, not
  `UserInputService` events, and each `InputContext` must sit under the owning `Player` so
  the engine knows whose input it is. Sanity-check the action values on the server side of
  the simulation as you would remote arguments.
- **Play effects and sounds outside the simulation.** The client simulation is a
  prediction that gets rolled back and re-run, so an effect fired inside it can play for a
  frame that never happened, or twice. Trigger effects and sounds from a separate function
  connected to `RenderStepped`, reading the simulation's result.
- **Remotes still carry discrete facts and requests,** but they are not ordered with
  property and attribute replication — do not assume a remote arrives before or after the
  state change it describes.
- **Force prediction per instance** with `RunService:SetPredictionMode()` when the
  automatic choice is wrong for an object.

## Testing

Test with latency and packet loss added to the playtest connection, and with at least two
clients. A solo playtest with zero latency never mispredicts, so it proves nothing about
rollback.

## Standing

Recorded. Every rule above is as of the stamp. The engine enforces only the *Simulation
Access* restriction; it does not stop a sound from double-firing or a `tick()` from
desynchronizing, and nothing in this plugin checks for either.
