# macOS Runner CI Tooling Maintenance

Every DJConnect macOS runner host uses this user LaunchAgent, not root
automation, because Apple builds, private-network relays and internal Apple
distribution use the runner user's Xcode toolchain, keychain and Homebrew
installation. Install it once per macOS host; multiple runner registrations
on the same host share the same maintained toolchain.

## Managed tooling

Daily at 10:00 local time and at user login, the task updates Homebrew metadata and
upgrades only already-installed CI helper formulae:

- `gh`
- `xcodegen`
- `swiftlint`
- `xcbeautify`
- `create-dmg`
- `mas`
- `node`

It records Xcode, Swift, Git, GitHub CLI, XcodeGen, Node and Python versions
in `~/Library/Logs/DJConnect/ci-tooling-maintenance.log` and writes a compact
success or failure status beside it. Missing optional formulae are recorded,
not installed implicitly.

Xcode itself is deliberately not changed unattended. A new Xcode, simulator
runtime or beta/stable transition can change signing, SDK and simulator
semantics. The current platform toolchain is therefore the latest *qualified*
Xcode line: qualify a new Xcode line first, then make it active and let this
task record the resulting version. This is not permission to retain an
unqualified, stale Xcode indefinitely.

## One-time installation

Run this as the same logged-in macOS user that runs the GitHub Actions runner:

```sh
cd <djconnect-app-clone>
bash scripts/runner/install_macos_ci_tooling_maintenance.sh --run-now
```

Do not use `sudo`. The installer copies the maintenance script to
`~/Library/Application Support/DJConnect/runner-maintenance/`, registers
`com.djconnect.ci-tooling-maintenance` in `~/Library/LaunchAgents/`, and waits
for the first execution to complete. Inspect the log and status files if it
reports a failure.
