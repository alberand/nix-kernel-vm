{
  description = "Linux Kernel development environment";

  nixConfig = {
    # override the default substituters
    extra-substituters = [
      "http://192.168.0.100"
    ];

    extra-trusted-public-keys = [
      "192.168.0.100:T4If+3X03bZC62Jh+Uzuz+ElERtgQFlbarUQE1PzC94="
    ];
  };

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
      vm = import ./system.nix {
        inherit nix-kernel-vm system nixpkgs pkgs root;
        inherit (import ./name.nix) name;
      };
    in {
      packages = {
        inherit (vm) vm iso kconfig;
      };
      devShells = {
        default = vm.shell;
      };
    });
}
