# Exiting VM
#   Use 'poweroff' command instead of CTRL-A X. Using the latter could lead to
#   corrupted root image and your VM won't boot (not always). However, it is
#   easily fixable by removing the image and running the VM again. The root
#   image is qcow2 file generated during the first run of your VM.
# Kernel Config:
#   Note that your kernel must have some features enabled. The list of features
#   could be found here https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix#L1142
{
  buildKernel,
  buildKernelConfig,
  nixpkgs,
}: {
  config,
  pkgs,
  lib,
  ...
}: {
  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor (
      buildKernel rec {
        inherit (pkgs.linuxPackages_latest.kernel) src version;
        inherit nixpkgs;
        modDirVersion = version;

        configfile = buildKernelConfig {
          inherit nixpkgs pkgs src version;
          structuredExtraConfig = with pkgs.lib.kernel; {
            XFS_FS = yes;
          };
        };
      }
    ));
    kernelParams = [
      # consistent eth* naming
      "net.ifnames=0"
      "biosdevnames=0"
      "console=ttyS0,115200n8"
      "console=tty0"
    ];
    consoleLogLevel = lib.mkDefault 7;
    # This is happens before systemd
    # postBootCommands = "echo 'Not much to do before systemd :)' > /dev/kmsg";
    crashDump.enable = true;
    initrd = {
      enable = true;
    };
  };

  system.requiredKernelConfig = with config.lib.kernelConfig; [
    # TODO fill this
    (isYes "SERIAL_8250_CONSOLE")
    (isYes "SERIAL_8250")
    (isEnabled "VIRTIO_CONSOLE")
  ];

  # Auto-login with empty password
  users.extraUsers.root.initialHashedPassword =
    "$y$j9T$TKzQNuxk898Qk7J6JC5NU1$xDW5NFyr0H/wW/k/MaTpbCRIMEsv.SbvBbj6Wu/1060"; # notsecret
  services.getty.autologinUser = lib.mkDefault "root";

  networking.firewall.enable = false;
  networking.hostName = lib.mkDefault "test-node";
  networking.useDHCP = true;
  #networking.interfaces.eth0 = {
  #  ipv4.addresses = [{
  #    address = "192.168.10.2";
  #    prefixLength = 24;
  #  }];
  #};

  # Not needed in VM
  documentation.doc.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  documentation.info.enable = false;
  programs.command-not-found.enable = false;

  # Do something after systemd started
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = ["getty.target"]; # to start at boot
    serviceConfig.Restart = "always"; # restart when session is closed
  };

  # Add packages to VM
  environment.systemPackages = with pkgs; [
    htop
    util-linux
    tmux
    fsverity-utils
    trace-cmd
    perf-tools
    linuxPackages_latest.perf
    openssl
    usbutils
    bpftrace
    xxd
    xterm
    neovim
    lvm2
    stress-ng
    fscrypt-experimental
    lsof
    gdb
  ];

  environment.variables = {
    EDITOR = "nvim";
  };

  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      PasswordAuthentication = true;
      # Allows all users by default. Can be [ "user1" "user2" ]
      AllowUsers = null;
      UseDns = true;
      X11Forwarding = false;
      # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
      PermitRootLogin = "yes";
    };
  };

  programs.bash.interactiveShellInit = let
    motd =
      pkgs.writeShellScriptBin "motd"
      ''
        #! /usr/bin/env bash

        echo "QEMU exit CTRL-A X"
        echo "libvirtd exit CTRL+]"
      '';
  in
    builtins.readFile "${motd}/bin/motd";

  system.stateVersion = "23.11";
}
