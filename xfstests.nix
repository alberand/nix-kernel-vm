{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.programs.xfstests;
  xfstests-overlay-remote = (self: super: {
    xfstests = super.xfstests.overrideAttrs (prev: {
      version = "git";
      src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfstests";
        rev = cfg.srcrev;
        sha256 = "sha256-iVuQWaFOHalHfkeUUXtlFkysB5whpeLFNK823wbaPj4=";
      };
    });
  });
in {
  options.programs.xfstests = {

    enable = mkEnableOption "hello service";
    srcrev = mkOption {
      type = types.str;
      default = "";
    };

  };

  config = mkIf cfg.enable {

    nixpkgs.overlays = [
      xfstests-overlay-remote
    ];

    # Setup envirionment
    environment.variables.HOST_OPTIONS = "/root/vmtest/xfstests-config";

    environment.systemPackages = with pkgs; [
      xfstests
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

    systemd.tmpfiles.rules = [
      "d /mnt 1777 root root"
      "d /mnt/test 1777 root root"
      "d /mnt/scratch 1777 root root"
    ];

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
  };
}
