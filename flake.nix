{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
    };
  in {
      nixosConfigurations = {
        "generic" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            ./vm.nix {
              environment.variables.EDITOR = "neovim";
              environment.systemPackages = [
                pkgs.vim
              ];
              users.users.hahahahaha = {
                isNormalUser  = true;
                description  = "Test user";
              };
            }
          ];
        };
      };

      overlays.default =
        (final: prev: {
          vmtest = pkgs.writeScriptBin "vmtest" "echo 'HAHA'";
        }) ;

      pkgs = {
        default = self.pkgs.vmtest;

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
          ${self.packages."${system}".vm}/bin/run-vm-vm
          echo "View results at $SHARE_DIR/results"
        '');

        vm = pkgs.symlinkJoin {
          name = "vm";
          paths = with self.nixosConfigurations.generic.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };
      };

      packages."${system}" = self.pkgs;

      apps."${system}".default = {
        type = "app";
        program = "${self.packages.${system}.vmtest}/bin/vmtest";
      };

    };
}
