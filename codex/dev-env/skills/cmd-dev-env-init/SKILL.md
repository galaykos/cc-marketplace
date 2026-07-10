---
name: cmd-dev-env-init
description: "Use when the user asks to scan the project's actual dependencies, propose a service plan, then generate docker-compose.yml (+ Dockerfile) to run it locally."
---

_This skill wraps the `/dev-env:init` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Invoke the compose-init skill from this plugin against $ARGUMENTS (or the
repository root if no argument). Steps:

1. If the stack-scan plugin is installed, run its installed-versions
   inventory first and reuse that report as the version evidence — do not
   re-scan what it already cited. Otherwise scan per the skill's version
   resolution order (composer.json/lock, package.json/engines/.nvmrc,
   .env DSNs, CI images, config/database.php). Read-only: never install or
   update anything to observe it.
2. Propose the service plan BEFORE writing files: one table of services with
   the pinned image tag, the evidence that demanded each service (source
   citation per row), and any `ASSUMED` markers with a one-line reason — plus
   the topology diagram per the skill's "Diagram before YAML" section (SVG on
   the live preview URL, or ASCII in chat for 3 services or fewer).
   Wait for confirmation.
3. Generate docker-compose.yml, and a multi-stage Dockerfile only when an
   official image plus compose config cannot run the project as-is. Never
   overwrite an existing docker-compose.yml, compose.yaml, or Dockerfile
   without showing a full diff against the current file and asking first.
4. Run the skill's verification protocol (`docker compose config -q`,
   `up -d --wait`, migrate, smoke curl) and report each command with its
   actual output. If Docker is unavailable, say so and list the exact
   commands the user must run — generated-but-unbooted is not done.
