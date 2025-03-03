{
  description = "Linux Kernel development environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    nix-kernel-vm.url = "github:alberand/nix-kernel-vm";
    nix-kernel-vm.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-kernel-vm,
  }:
    flake-utils.lib.eachDefaultSystem (_: let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      root = builtins.toString ./.;
      vmtest = import ./system.nix {
        inherit nix-kernel-vm system nixpkgs pkgs root;
      };
    in {
      packages = {
        inherit vmtest;
      };
      devShells = {
        vmtest = vmtest.shell;
      };
    });
}
