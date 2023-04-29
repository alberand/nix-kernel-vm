{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, pkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in rec {
    lib = {
      mkSys = {xfstests-src, xfsprogs-src}: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./vm.nix
          ({ config, pkgs, ... }: {
            programs.xfstests = {
              enable = true;
              src = xfstests-src;
            };

            nixpkgs.overlays = [
              (self: super: {
                xfsprogs = super.xfsprogs.overrideAttrs (prev: {
                  version = "git";
                  src = xfsprogs-src;
                });
              })
            ];
          })

        ];
      };
      mkVmTest = { pkgs, xfstests-src, xfsprogs-src }: builtins.getAttr "vmtest" rec {
        nixos = lib.mkSys {
          inherit xfstests-src xfsprogs-src;
        };

        vm-system = pkgs.symlinkJoin {
          name = "vm-system";
          paths = with nixos.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
            ${vm-system}/bin/run-vm-vm
            echo "View results at $SHARE_DIR/results"
        '');
      };
    };

    pkgs.vmtest = (lib.mkVmTest {
      inherit pkgs;
      xfstests-src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfstests";
        rev = "f64ffc3dc27e155f80c9d42629d9131106d8e404";
        sha256 = "sha256-qinniYrWmw1kKuvhrt32Kp1oZCIG/tyyqNKISU5ui90=";
      };

      xfsprogs-src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfsprogs";
        rev = "91bf9d98df8b50c56c9c297c0072a43b0ee02841";
        sha256 = "sha256-otEJr4PTXjX0AK3c5T6loLeX3X+BRBvCuDKyYcY9MQ4=";
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
