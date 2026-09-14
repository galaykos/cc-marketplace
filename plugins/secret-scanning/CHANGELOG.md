# Changelog

All notable changes to the `secret-scanning` plugin. Entries start at 0.5.0; earlier
releases were not recorded here and are not reconstructed.

## 0.5.0

### Fixed
- **A fixture write could not get past the guard.** The deny is unbounded and has no
  allow-file, and the reason text's own advice — "use an obviously-fake value" — was
  unfollowable for the shapes that actually came up: AWS's documented example key
  `AKIAIOSFODNN7EXAMPLE` matches the AKIA shape by construction, and an
  `.env.example` line such as `STRIPE_SECRET=` followed by a test-key prefix and a
  run of `x`s matches the assigned-literal shape. Every retry was refused; the only exits were a
  Bash heredoc around the guard or uninstalling it. A matched VALUE is now released
  when it announces itself as a placeholder: it ends in `EXAMPLE`, is one character
  repeated, or carries a placeholder word (`example`, `placeholder`, `changeme`,
  `your-`/`your_`, `dummy`, `redacted`, `sample`, `fake`, `todo`, `xxxx`). The test
  reads the value only, never the variable name, and every match in a write is
  checked. Residual, stated in the hook header: a real secret containing one of those
  words passes. Ten harness cases (`scripts/__tests__/scan-hook.test.sh`) cover both
  directions.
- Deny reasons read "contain an AWS access key ID" / "an assigned secret literal"
  instead of "a AWS …" / "a assigned …", and now say what a fixture value must look
  like to pass.
