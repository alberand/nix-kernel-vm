{
  nix-kernel-vm,
  system,
  nixpkgs,
  pkgs,
  root,
  name ? "vm",
}: let
  # Global name used for image deploy, node hostname
  inherit name;
  user-config = {
    imports = [./sources.nix];

    programs = {
      # Custom version can be used
      xfstests = {
        enable = true;
        # To create a custom config commit a config to this repository and use
        # (builtins.readFile ./your-config)
        testconfig = nix-kernel-vm.packages.${system}.xfstests-configs.xfstests-all;
      };

      xfsprogs = {
        enable = true;
      };
    };
  };
in {
  shell =
    (nix-kernel-vm.lib.${system}.mkLinuxShell {
      inherit pkgs root name;
      pname = "kernel"; # don't change
    })
    .overrideAttrs (_final: prev: {
      shellHook =
        prev.shellHook
        + ''
          echo "$(tput setaf 161)Welcome to kernel dev-shell.$(tput sgr0)"
        '';
    });

  kconfig = nix-kernel-vm.lib.${system}.buildKernelConfig {
    src = pkgs.fetchFromGitHub {
      owner = "alberand";
      repo = "linux";
      rev = "xfs-xattrat";
      hash = "sha256-PTR5lUeULW9hbe8VUPuvtTf5jG92D7UFr0WmvlLcgUw=";
    };
    version = "xfs-xattrat";
    kconfig = with pkgs.lib.kernel; {
      FS_VERITY = yes;
    };
  };

  iso = nix-kernel-vm.lib.${system}.mkIso {
    inherit pkgs user-config;
    test-disk = "/dev/sda";
    scratch-disk = "/dev/sdb";
  };

  vm = nix-kernel-vm.lib.${system}.mkVmTest {
    inherit pkgs;
    user-config =
      user-config
      // {
        vm.disks = [5000 5000];
      };
  };
}
