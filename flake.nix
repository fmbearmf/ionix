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

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.python3
            ];
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-tree);
    };
}
