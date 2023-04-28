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
            ./vm.nix
          ];
        };
      };

      overlays.default = (self: super: {
        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
          ${pkgs.vm-system}/bin/run-vm-vm
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
      });

      packages.${system} = rec {
        default = pkgs.vmtest;
        vmtest = pkgs.vmtest;
      };

      apps.${system}.default = flake-utils.lib.mkApp {
        drv = pkgs.vmtest;
      };
    };
}
