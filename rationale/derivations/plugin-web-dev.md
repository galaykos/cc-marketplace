# web-dev: derivations for files whose header points here

Standing: `recorded` — no gate reads this file.

## plugins/web-dev/hooks/expo-prebuild-guard.sh

What made it exist: Expo SDK 57 changed `expo prebuild` to clear and regenerate `ios/` and
`android/` by default (`--no-clean` opts out; `--clean` is kept as a no-op). The habit of a bare
`npx expo prebuild`, which used to layer onto existing files, now wipes them. The skill text
(`skills/react-native-best-practices/references/expo.md`, "CNG: from SDK 57 prebuild cleans by
DEFAULT") states the rule, but nothing read it at the moment the command ran. The 2026-11-21
thinking-disciplines follow-up review (UI and web plugins, finding 1) proposed this ask; the user
approved it on 2026-11-21.

When it asks. It asks only when the wipe can lose work git cannot give back, or work that is source:
`git status --porcelain --untracked-files=all` shows anything under the native dirs, or
`git ls-files` lists more tracked native files than `git ls-files -ci --exclude-standard` does,
which is the bare regime in expo.md's table. A CNG project whose native dirs are gitignored and
untracked gets no ask, because there they are build output. Outside git it asks whenever either
dir exists. Below SDK 57 (installed `node_modules/expo`, else the `package.json` range) a bare
prebuild does not clean, so only a typed `--clean` asks. An unreadable version counts as 57+.

Why an ask and not a deny: a deliberate regeneration is legitimate, and the person can approve it.

Limits: `npm run prebuild` and other wrappers, `eas build --local`, a `cd` through a variable,
and `--platform` spellings other than `--platform <p>` / `-p <p>` are not followed.
The harness is `plugins/web-dev/scripts/__tests__/expo-prebuild-guard.test.sh`.
