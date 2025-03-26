{
  description = "kd - Linux Kernel development toolset";

  nixConfig = {
    # override the default substituters
    # TODO this need to be replaced with public bucket or something
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
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixos-generators,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (_final: prev: {
            xfstests-configs = (import ./xfstests/configs.nix) {pkgs = prev;};
          })
        ];
      };
      # default kernel if no custom kernel were specified
      lib = import ./lib.nix {
        inherit pkgs nixos-generators nixpkgs;
      };
      default = lib.mkEnv {
        name = "demo";
        root = builtins.toString ./.;
      };
    in {
      inherit lib;

      devShells.default = default.shell;

      packages = {
        inherit (default) kconfig kconfig-iso headers kernel iso vm;
      };

      templates.vm = {
        path = ./templates/vm;
        description = "Development shell for Linux kernel with image builder";
        welcomeText = ''
          This is template for testing Linux kernel with xfstests.
        '';
      };
      templates.default = self.templates.vm;
    });
}
