# macOS Runner CI Tooling Maintenance

Every DJConnect macOS runner host uses this user LaunchAgent, not root
automation, because Apple builds, private-network relays and internal Apple
distribution use the runner user's Xcode toolchain, keychain and Homebrew
installation. Install it once per macOS host; multiple runner registrations
on the same host share the same maintained toolchain.

## Managed tooling

Daily at 10:00 local time and at user login, the task updates Homebrew metadata
and every already-installed formula. It then updates each outdated Homebrew
cask independently. It never installs missing packages.

It also maintains the development-network tooling without handling secrets:

- the installed Homebrew `ngrok` cask is upgraded as part of the cask pass;
  its tunnel, auth token and LaunchAgent configuration are untouched;
- Tailscale remains on its signed-app auto-update channel. The task verifies
  that automatic update is enabled but never replaces an independently
  installed Tailscale app with Homebrew.

Some casks, such as `dotnet-sdk`, can require an interactive macOS
administrator authorization to replace system-owned files. The user
LaunchAgent deliberately has no passwordless `sudo` access. It records those
casks as `SUCCESS (ADMIN MAINTENANCE REQUIRED: ...)`, continues all other
updates and remains healthy. Perform the named cask update from an interactive
administrator terminal, for example:

```sh
brew upgrade --cask dotnet-sdk
```

Do not add `brew` to `sudoers`; that would turn the user-maintained Homebrew
environment into a root execution path.

It records Xcode, Swift, Git, GitHub CLI, XcodeGen, Node and Python versions
in `~/Library/Logs/DJConnect/ci-tooling-maintenance.log` and writes a compact
success or failure status beside it. Missing optional formulae are recorded,
not installed implicitly.

Xcode installed through Xcodes, the App Store or Apple developer downloads is
not changed by Homebrew. If an operator deliberately installs Xcode as a
Homebrew cask, the all-cask policy includes it; qualifying a new Xcode line
before it becomes the selected runner toolchain remains required.

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
