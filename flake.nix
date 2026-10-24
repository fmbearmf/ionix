{
  description = "Ionix web framework";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs =
    inputs:
    let
      eachSystem = f: builtins.mapAttrs f inputs.nixpkgs.legacyPackages;

      ionix = import ./lib {
        inherit (inputs.nixpkgs) lib;
      };
    in
    {
      lib = ionix;

      packages = eachSystem (
        system: pkgs: {
          css-engine = ionix.cssEngine pkgs;
          example-site = import ./examples/site { inherit pkgs ionix; };
          default = ionix.cssEngine pkgs;
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.stdenv.cc
              pkgs.clang-tools
              pkgs.python3
            ];
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-tree);
    };
}
