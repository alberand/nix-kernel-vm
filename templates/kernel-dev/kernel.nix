{
  nix-kernel-vm,
  system,
  nixpkgs,
  pkgs,
  root,
}: let
  # Global name used for image deploy, node hostname
  name = "kernel";
  user-config = {
    # Hostname to identify the node
    networking.hostName = name;
    # Your ssh key to connect to node with root user
    users.users.root.openssh.authorizedKeys.keys = [
      (
        builtins.readFile
        (
          if ! builtins.pathExists ./ssh-key.pub
          then abort "Please provide ./ssh-key.pub"
          else ./ssh-key.pub
        )
      )
    ];
    # Any additional packages to include into the image
    # https://search.nixos.org/packages
    environment.systemPackages = with pkgs; [
      btrfs-progs
      f2fs-tools
      keyutils
    ];
    # Kernel version
    boot.kernelPackages = let
      linux-custom-pkg = {
        fetchurl,
        buildLinux,
        ...
      } @ args:
        buildLinux (args
          // rec {
            version = "6.13-rc4";
            modDirVersion = version;

            src = pkgs.fetchgit {
              url = "git@github.com:alberand/linux.git";
              rev = "9c913654d7bb78d9132eb32b1ed7739674c75e8c";
              sha256 = "sha256-uP7gBhVhGxy0ADazteJ5u1vvftlCua8jTkylwDrLQZY=";
            };
            kernelPatches = [];

            extraConfig = '''';
          }
          // (args.argsOverride or {}));
      linux-custom = pkgs.callPackage linux-custom-pkg {};
    in
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux-custom);
    # Get ip
    networking.useDHCP = pkgs.lib.mkForce true;

    programs = {
      # Custom version can be used
      xfstests = {
        enable = true;
        src = pkgs.fetchgit {
          url = "git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git";
          rev = "v2024.12.22";
          sha256 = "sha256-xZkCZVvlcnqsUnGGxSFqOHoC73M9ijM5sQnnRqamOk8=";
        };
        # To create a custom config commit a config to this repository and use
        # (builtins.readFile ./your-config)
        testconfig = nix-kernel-vm.packages.${system}.configs.xfstests.xfstests-all;
        test-dev = "/dev/sda";
        scratch-dev = "/dev/sdb";
        arguments = "-R xunit -s xfs_4k -g auto";
      };

      xfsprogs = {
        enable = true;
        src = pkgs.fetchgit {
          url = "git://git.kernel.org/pub/scm/linux/kernel/git/aalbersh/xfsprogs-dev.git";
          rev = "v6.12.0";
          sha256 = "sha256-AXLIqn30Wl6Ry1NNzhurQkCSGXq5G8IyAjxXEVKskTk=";
        };
      };
    };
  };
in {
  shell =
    (nix-kernel-vm.lib.${system}.mkLinuxShell {
      inherit pkgs root name;
      no-vm = true;
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
