---
name: omp-nix-patched-fork-auto-rebuild
description: "Use when maintaining Sylonin/omp-nix: patched omp release workflow, patches/*.patch no longer applying, verifying a patch."
---

# Sylonin/omp-nix: patched omp builds

Repo: Sylonin/omp-nix (local `~/Proj/p/omp-nix`), a fork of an omp-nix-style flake packaging the prebuilt Bun single-file-executable CLI (`package.nix` takes `version`/`url`/`nixHash` as `callPackage` args). `.github/workflows/build.yml` applies `patches/*.patch` to each new upstream (can1357/oh-my-pi) release and republishes a patched binary consumed by the NixOS flake. It also triggers on pushes touching `patches/**`.

## Design (why it is not a rebase)
GITHUB_TOKEN cannot push commits touching `.github/workflows/*` (needs a `workflow` scope), so a rebase-and-force-push design breaks when upstream CI files change. Instead, each scheduled run:

1. Compares upstream's latest *GitHub release* tag (`gh release view -R <upstream> --json tagName -q .tagName`; excludes prereleases/canaries) plus a hash of `patches/*.patch` against the `version`/`patches` pair in `versions.json`; skips if both match.
2. Skips (not fails) if the platform's native addon npm package for that version doesn't exist yet (`npm view @scope/pkg-native-<platform>@<version> version`); release assets and npm builds publish out of order and the next run retries.
3. Checks out upstream fresh at the tag into a subdirectory, then `git apply ../patches/*.patch`. A patch that no longer applies fails the job loudly; that failure (GitHub emails it) is the signal a human must rebase the patch. Never silently degrade to an unpatched build.
4. Builds with upstream's CI script (e.g. `bun run ci:release:build-binaries` with `RELEASE_TARGETS=<platform>`), skipping the Rust/Bazel compile by downloading the platform native addon from npm's tarball and feeding it to the local installer (`bun scripts/bazel-natives.ts <target> --source <dir> --dest <dest>`).
5. Smoke-tests the binary (`--version`, `--smoke-test`) before publishing.
6. Publishes a GitHub release tagged `v<version>-p<patch-hash-prefix>`; never reuse a bare `v<version>` across patch changes or old `flake.lock` pins resolve to different bytes.
7. Computes the SRI hash with `openssl dgst -sha256 -binary <file> | base64` prefixed `sha256-`.
8. Writes `version`/`patches`/`url`/`hash` into `versions.json`, runs `nix build .#default` in the same job before committing.
9. Commits only `versions.json` with the default token, so workflow files are never touched.

Scoping: if the consumer needs one platform (x86_64-linux), trim `versions.json` and `flake.nix` `supportedSystems`/`platformMap` to it; half-built platforms pointing at unpatched binaries are worse than none.

## Fix: patch no longer applies to a new release
1. `gh run list -R Sylonin/omp-nix --limit 4` to confirm the failure (always pass `-R`; without it `gh` may show yuxqiu/omp-nix). Target tag: `gh release view -R can1357/oh-my-pi --json tagName -q .tagName`.
2. `git clone --depth 1 https://github.com/can1357/oh-my-pi /tmp/up`; `git apply --check -v <patch>` shows the failing hunk (usually drifted context such as imports).
3. Re-apply the patch's intent by hand in /tmp/up, then `git diff > patches/<name>.patch`.
4. Verify: `git stash; git apply --check patches/*.patch; git stash pop` in /tmp/up.
5. Commit `fix(patches): rebase <name> onto vX.Y.Z` and push; the push triggers a build. `gh run watch <id> -R Sylonin/omp-nix --exit-status`. The run publishes the release and commits `versions.json` itself.

## Verify a patch end to end without API credits
For an auth/security-gate style patch, build the patched binary and exercise only the preflight/plan-creation path against an **isolated copy** of the credential store: copy `~/.omp/agent/agent.db` and `config.yml` into a tmpdir, point `PI_CODING_AGENT_DIR` at it, run from a throwaway git repo. Compare stock (rejects) vs patched (accepts) output.

To confirm the CI-built artifact contains the fix (not just your local build), don't trust release notes: `nix flake update <input>` in the consuming flake, `nix build github:<fork>/omp-nix#default`, and rerun the isolated check on that store path.
