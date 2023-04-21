{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
    };
  in rec {
      nixosConfigurations = {
        "generic" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ({ config, pkgs, ... }: { nixpkgs.overlays = [ self.overlays.default ]; })
            ./vm.nix
          ];
        };
      };

      overlays.default = (self: super: {
        xfstests = super.xfstests.overrideAttrs (prev: {
          version = "git";
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "xfstests";
            rev = "00b52cf1a66eb5d84567ab3afe8365e1b3664289";
            sha256 = "sha256-e0w+Qqt7Dro+FVf3Ut/GN7HMjq4oU/rvmDbqCq9WiA4=";
          };
        });
      });

      packages.${system} = rec {
        default = packages.${system}.vmtest;

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
          ${packages.${system}.vm-system}/bin/run-vm-vm
          echo "View results at $SHARE_DIR/results"
        '');

        vm-system = pkgs.symlinkJoin {
          name = "vm-system";
          paths = with nixosConfigurations.generic.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };
      };

      apps.${system}.default = flake-utils.lib.mkApp {
        drv = packages.${system}.vmtest;
      };
    };
}
