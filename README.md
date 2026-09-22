# omp-nix (patched)

Nix flake for [Oh My Pi](https://github.com/can1357/oh-my-pi), built from each upstream release with the patches in `patches/` applied. Only `x86_64-linux` is built.

`.github/workflows/build.yml` runs every 2 hours and on changes to `patches/`. When the latest upstream release or the patch set differs from `versions.json`, it:

1. Checks out the upstream release tag and applies `patches/*.patch`.
2. Installs the matching `@oh-my-pi/pi-natives-linux-x64` addons from npm, so no Rust build is needed.
3. Builds and smoke-tests `omp-linux-x64`.
4. Publishes it as release `v<version>-p<patch hash>`, updates `versions.json`, verifies `nix build`, and commits.

A patch that no longer applies fails the run; fix the patch and push.

```nix
{
  inputs.omp-nix.url = "github:Sylonin/omp-nix";
  # inputs.omp-nix.packages.x86_64-linux.default
}
```
