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
      src = pkgs.fetchFromGitHub {
        owner = "torvalds";
        repo = "linux";
        rev = "v6.13";
        hash = "sha256-FD22KmTFrIhED5X3rcjPTot1UOq1ir1zouEpRWZkRC0=";
      };
    in
      pkgs.linuxPackagesFor
      (nix-kernel-vm.lib.${system}.buildKernel
        {
          inherit src;
          version = "v6.13";
          modDirVersion = "6.13.0";
          kconfig = nix-kernel-vm.lib.${system}.buildKernelConfig {
            inherit src;
            version = "v6.13";
            kconfig = with pkgs.lib.kernel; {
              FS_VERITY = yes;
              XFS_FS = yes;
              XFS_QUOTA = yes;
            };
          };
        });
    # Get ip
    networking.useDHCP = pkgs.lib.mkForce true;

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
