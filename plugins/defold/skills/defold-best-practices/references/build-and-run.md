# Build and smoke-run with Bob

> Last verified: 2026-10-26 — https://defold.com/manuals/bob/

The commands and error strings here come from Bob 1.14.0 (sha1
`d295ed4edff2e49072719835713e625f409849f1`) on Linux x86_64, and from the official
[Bob manual](https://defold.com/manuals/bob/) and
[automated testing manual](https://defold.com/manuals/automated-testing/).

## Tools

- **Java.** Bob 1.14.0 needs OpenJDK 25. Under Java 21 it fails at once with
  `UnsupportedClassVersionError … class file version 69.0`.
- **`bob.jar` matching the project's version.** The current stable release, with its
  version and sha1, is at https://d.defold.com/stable/info.json. Download by version from
  `https://github.com/defold/defold/releases/download/<version>/bob.jar`, or by sha1 from
  `https://d.defold.com/archive/stable/<sha1>/bob/bob.jar`.
- `java -jar bob.jar --version` prints the version, sha1 and channel.

## Commands

Bob runs the commands you list, in order: `resolve` fetches library dependencies into
`.internal/lib/`, then `clean`, `distclean`, `build`, `bundle`.

```sh
# Compile everything reachable from game.project into build/default
java -jar bob.jar --root . --variant headless --archive resolve build

# Release desktop bundle
java -jar bob.jar --root . --archive --platform x86_64-linux --variant release \
  --bundle-output ../dist resolve distclean build bundle

# Machine-readable report of what was built
java -jar bob.jar --root . --archive --build-report-json ../report.json resolve build
```

- Platforms: `x86_64-linux`, `arm64-linux`, `x86_64-win32`, `x86_64-macos`, `arm64-macos`,
  `arm64-ios`, `arm64_sim-ios`, `armv7-android`, `wasm-web`.
- Variants: `debug` (the default), `release`, `headless` (a null graphics device).
- `bundle` needs `--archive` and `--platform`, and `--bundle-output` must point outside the
  project's `build/` folder.
- `--settings file.settings` overlays `game.project` keys. Several files apply left to
  right. Use it for a test bootstrap instead of editing `game.project`.
- The bundle lands in a folder named after `project.title`. The executable inside is named
  after the title with the spaces removed (`Defold Core Example/DefoldCoreExample.x86_64`).
- A build error exits 1. Read the line starting `ERROR`; the `SEVERE` lines after it are
  the Java stack trace. A missing resource property
  (`go.property("art", resource.atlas("/main/nope.atlas"))`) shows up ONLY in those
  `SEVERE` lines: `Resource '/main/nope.atlas' referenced from script resource property
  'art' does not exist`.

## Smoke-test a running game

A build proves the resources compile, not that the scripts run. Give the project a test
bootstrap: it loads the real main collection through a proxy, lets it run, prints a
marker and exits. These three files and the commands under them ran as shown on 1.14.0.

`test/smoke.settings`:

```ini
[bootstrap]
main_collection = /test/smoke.collectionc
```

`test/smoke.collection` — its `name` must differ from the main collection's, because both
worlds are loaded at once:

```text
name: "smoke"
embedded_instances {
  id: "smoke"
  data: "components {\n"
  "  id: \"smoke\"\n"
  "  component: \"/test/smoke.script\"\n"
  "}\n"
  "embedded_components {\n"
  "  id: \"game\"\n"
  "  type: \"collectionproxy\"\n"
  "  data: \"collection: \\\"/main/main.collection\\\"\\n\"\n"
  "  \"\"\n"
  "}\n"
  ""
}
scale_along_z: 0
```

`test/smoke.script`:

```lua
go.property("seconds", 2)

local PROXY_LOADED = hash("proxy_loaded")

function init(self)
	msg.post(".", "acquire_input_focus")
	msg.post("#game", "load")
	self.time = 0
end

function update(self, dt)
	self.time = self.time + dt
	if self.time >= self.seconds then
		print("SMOKE done")
		sys.exit(0)
	end
end

function on_message(self, message_id, message, sender)
	if message_id == PROXY_LOADED then
		msg.post(sender, "init")
		msg.post(sender, "enable")
	end
end
```

```sh
java -jar bob.jar --root . --settings test/smoke.settings --platform x86_64-linux \
  --variant headless --archive --bundle-output ../smoke-bundle resolve build bundle
timeout 30 "../smoke-bundle/Defold Core Example/DefoldCoreExample.x86_64" > run.log 2>&1
grep -q "SMOKE done" run.log && ! grep -q "^ERROR:" run.log && echo PASS
```

Judge the run by the log:

- A Lua error in a callback prints `ERROR:SCRIPT: main/x.script:8: attempt to index …` with
  a traceback, and the engine keeps running. Without a timeout the test hangs; with one,
  the run ends with the timeout's status (124 for GNU `timeout`).
- A main collection that cannot be created — a `require` that fails at load, for instance —
  exits 1 after `ERROR:GAMEOBJECT: Could not instantiate game object from prototype …`.
- A bad message target logs `ERROR:GAMEOBJECT: Instance '/x' could not be found when
  dispatching message` and the game carries on, so grep for it explicitly.
- For many assertions, print one structured line per result (the automated-testing manual
  suggests a prefix such as `TEST {json}`), and fail the run when the final line is
  missing.

The headless engine binary can also run a plain build from the project root, where it
loads `build/default/game.dmanifest`. It is published next to `bob.jar`
(`https://d.defold.com/archive/stable/<sha1>/engine/x86_64-linux/dmengine_headless`),
but no manual documents it. Prefer the headless bundle when you need a documented path.

## Ports and parallel runs

A debug or headless engine opens an engine service on port 8001, a log server on a random
port, and the Remotery profiler on `ws://127.0.0.1:17815`. A second engine started at the
same time logs `ERROR:PROFILER: Failed to initialize Remotery`. Run one engine per test
job, always under a timeout, and confirm it has exited before the next run starts.
