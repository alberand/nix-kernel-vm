# Create two disks:
#   xfs_io -f -c "falloc 0 13g" {test,scratch}.img
# Build VM with:
#   nix-build '<nixpkgs/nixos>' -A vm --arg configuration ./vm.nix
# Exiting VM
#   Use 'poweroff' command instead of CTRL-A X. Using the latter could lead to
#   corrupted root image and your VM won't boot (not always). However, it is
#   easily fixable by removing the image and running the VM again. The root
#   image is qcow2 file generated during the first run of your VM.
# Kernel Config:
#   Note that your kernel must have some features enabled. The list of features
#   could be found here https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix#L1142
{ config, modulesPath, pkgs, lib, ... }: let
  xfstests-overlay-remote = (self: super: {
    xfstests = super.xfstests.overrideAttrs (prev: {
      version = "git";
      src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfstests";
        rev = "cbb3b25d72361c4c6c141b03312e7ac2f5d1e303";
        sha256 = "sha256-iVuQWaFOHalHfkeUUXtlFkysB5whpeLFNK823wbaPj4=";
      };
    });
  });

  xfsprogs-overlay-remote = (self: super: {
    xfsprogs = super.xfsprogs.overrideAttrs (prev: {
      version = "6.6.2";
      src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfsprogs";
        rev = "91bf9d98df8b50c56c9c297c0072a43b0ee02841";
        sha256 = "sha256-otEJr4PTXjX0AK3c5T6loLeX3X+BRBvCuDKyYcY9MQ4=";
      };
    });
  });
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  boot = {
    kernelParams = ["console=ttyS0,115200n8" "console=ttyS0"];
    consoleLogLevel = lib.mkDefault 7;
    # This is happens before systemd
    postBootCommands = "echo 'Not much to do before systemd :)' > /dev/kmsg";
    crashDump.enable = true;

    # Set my custom kernel
    # kernelPackages = kernel-custom;
    kernelPackages = pkgs.linuxKernel.packagesFor pkgs.linuxKernel.kernels.linux_6_2;
  };

  # Auto-login with empty password
  users.extraUsers.root.initialHashedPassword = "";
  services.getty.autologinUser = lib.mkDefault "root";

  networking.firewall.enable = false;
  networking.hostName = "vm";
  networking.useDHCP = false;
  services.getty.helpLine = ''
          Log in as "root" with an empty password.
          If you are connect via serial console:
          Type CTRL-A X to exit QEMU
  '';

  # Not needed in VM
  documentation.doc.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  documentation.info.enable = false;
  programs.bash.enableCompletion = false;
  programs.command-not-found.enable = false;

  systemd.tmpfiles.rules = [
    "d /mnt 1777 root root"
    "d /mnt/test 1777 root root"
    "d /mnt/scratch 1777 root root"
  ];
  # Do something after systemd started
  systemd.services."serial-getty@ttyS0".enable = true;
  systemd.services.xfstests = {
    enable = true;
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "tty";
      StandardError = "tty";
      User = "root";
      Group = "root";
      WorkingDirectory = "/root";
    };
    after = [ "network.target" "network-online.target" "local-fs.target" ];
    wants = [ "network.target" "network-online.target" "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    postStop = ''
                  # Handle case when there's no modules glob -> empty
                  shopt -s nullglob
                  for module in /root/vmtest/modules/*.ko; do
                          ${pkgs.kmod}/bin/rmmod $module;
                  done;
                  # Auto poweroff
                  # ${pkgs.systemd}/bin/systemctl poweroff;
    '';
    script = ''
                  # Handle case when there's no modules glob -> empty
                  shopt -s nullglob
                  for module in /root/vmtest/modules/*.ko; do
                          ${pkgs.kmod}/bin/insmod $module;
                  done;

                  ${pkgs.bash}/bin/bash -lc \
                          "${pkgs.xfstests}/bin/xfstests-check -d $(cat /root/vmtest/totest)"
                  # Beep beep... Human... back to work
                  echo -ne '\007'
    '';
  };

  # Setup envirionment
  environment.variables.HOST_OPTIONS = "/root/vmtest/xfstests-config";

  networking.interfaces.eth1 = {
    ipv4.addresses = [{
      address = "192.168.10.2";
      prefixLength = 24;
    }];
  };

  virtualisation = {
    diskSize = 20000; # MB
    memorySize = 4096; # MB
    cores = 4;
    writableStoreUseTmpfs = false;
    useDefaultFilesystems = true;
    # Run qemu in the terminal not in Qemu GUI
    graphics = false;

    qemu = {
      networkingOptions = [
        "-device e1000,netdev=network0,mac=00:00:00:00:00:00"
        "-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"
      ];
    };

    sharedDirectories = {
      results = {
        source = "/tmp/vmtest/results";
        target = "/root/results";
      };
      vmtest = {
        source = "/tmp/vmtest";
        target = "/root/vmtest";
      };
    };
  };

  # Add packages to VM
  environment.systemPackages = with pkgs; [
    htop
    util-linux
    xfstests
    tmux
    fsverity-utils
    trace-cmd
    perf-tools
    linuxPackages_latest.perf
    openssl
    xfsprogs
    usbutils
    bpftrace
    xxd
    xterm
  ];

  services.openssh.enable = true;

  # Apply overlay on the package (use different src as we replaced 'src = ')
  nixpkgs.overlays = [
    xfstests-overlay-remote
    xfsprogs-overlay-remote
  ];

  users.users.fsgqa = {
    isNormalUser  = true;
    description  = "Test user";
  };

  users.users.fsgqa2 = {
    isNormalUser  = true;
    description  = "Test user";
  };

  users.users.fsgqa-123456 = {
    isNormalUser  = true;
    description  = "Test user";
  };

  system.stateVersion = "22.11";
}
