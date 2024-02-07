# Exiting VM
#   Use 'poweroff' command instead of CTRL-A X. Using the latter could lead to
#   corrupted root image and your VM won't boot (not always). However, it is
#   easily fixable by removing the image and running the VM again. The root
#   image is qcow2 file generated during the first run of your VM.
# Kernel Config:
#   Note that your kernel must have some features enabled. The list of features
#   could be found here https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix#L1142
{ config, pkgs, lib, ... }: {
  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    kernelParams = [
      # consistent eth* naming
      "net.ifnames=0"
      "biosdevnames=0"
      "console=ttyS0,115200n8"
      "console=ttyS0"
    ];
    consoleLogLevel = lib.mkDefault 7;
    # This is happens before systemd
    postBootCommands = "echo 'Not much to do before systemd :)' > /dev/kmsg";
    crashDump.enable = true;
  };

  system.requiredKernelConfig = with config.lib.kernelConfig; [
    # TODO fill this
    (isYes "SERIAL_8250_CONSOLE")
    (isYes "SERIAL_8250")
    (isEnabled "VIRTIO_CONSOLE")
  ];

  # Auto-login with empty password
  users.extraUsers.root.initialHashedPassword = "";
  services.getty.autologinUser = lib.mkDefault "root";

  networking.firewall.enable = false;
  networking.hostName = "test-node";
  networking.useDHCP = true;
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

  # Do something after systemd started
  systemd.services."serial-getty@ttyS0".enable = true;

  #networking.interfaces.eth0 = {
  #  ipv4.addresses = [{
  #    address = "192.168.10.2";
  #    prefixLength = 24;
  #  }];
  #};

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
  ];

  environment.variables = {
    EDITOR = "nvim";
  };

  environment.interactiveShellInit = ''
    alias vim='nvim'
  '';

  services.openssh.enable = true;

  system.stateVersion = "23.05";
}
