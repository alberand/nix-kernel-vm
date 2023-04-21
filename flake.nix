{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    xfsprogs = {
      type = "github";
      owner = "alberand";
      repo = "xfsprogs";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, xfsprogs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
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

      packages."${system}" ={
        default = self.packages."${system}".vmtest;

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

      apps."${system}".default = {
        type = "app";
        program = "${self.packages.${system}.vmtest}/bin/vmtest";
      };

    };
}
