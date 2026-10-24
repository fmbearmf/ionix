# non-flake entry point for the plebians

{
  pkgs ? import <nixpkgs> { },
}:

let
  framework = import ./lib { inherit (pkgs) lib; };
in
framework
// {
  mkSite = args: framework.mkSite (args // { inherit pkgs; });
}
