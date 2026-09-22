{
  description = "Oh My Pi built from upstream releases with local patches";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      manifest = builtins.fromJSON (builtins.readFile ./versions.json);
      build = pkgs:
        pkgs.callPackage ./package.nix {
          inherit (manifest) version url;
          nixHash = manifest.hash;
        };
    in {
      packages.${system} = rec {
        oh-my-pi = build nixpkgs.legacyPackages.${system};
        default = oh-my-pi;
      };

      overlays.default = final: prev: { oh-my-pi = build final; };
    };
}
