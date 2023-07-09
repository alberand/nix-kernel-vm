{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.programs.xfstests;
  xfstests-overlay-remote = (self: super: {
    xfstests = super.xfstests.overrideAttrs (prev: {
      version = "git";
      src = cfg.src;
    });
  });
in {
  options.programs.xfstests = {
    enable = mkEnableOption {
      name = "xfstests";
      default = true;
      example = true;
    };

    arguments = mkOption {
      description = "command line arguments for xfstests";
      default = "";
      example = "-g auto";
      type = types.str;
    };

    testconfig = mkOption {
      description = "xfstests configuration file";
      default = null;
      example = "./local.config.example";
      type = types.path;
    };

    autoshutdown = mkOption {
      description = "autoshutdown machine after test is complete";
      default = false;
      example = false;
      type = types.bool;
    };

    src = mkOption {
      type = types.package;
    };

  };

  config = mkIf cfg.enable {

    nixpkgs.overlays = [
      xfstests-overlay-remote
      # Apply xfsprogs fix
      (final: prev: {
        xfsprogs = prev.xfsprogs.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            ./0001-fix-nix-make-doesn-t-have-enough-permission-to-chang.patch
          ];
        });
      })
    ];

    environment.systemPackages = with pkgs; [
      xfsprogs
    ];

    # Setup envirionment
    environment.variables.HOST_OPTIONS = "/root/vmtest/xfstests-config";

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

    users.groups.fsgqa.members = [ "fsgqa" ];
    users.groups.fsgqa2.members = [ "fsgqa2" ];
    users.groups.fsgqa-123456.members = [ "fsgqa-123456" ];

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
                  # Beep beep... Human... back to work
                  echo -ne '\007'
      '' + optionalString cfg.autoshutdown ''
                  # Auto poweroff
                  ${pkgs.systemd}/bin/systemctl poweroff;
      '';
      script = ''
                  ${pkgs.bash}/bin/bash -lc \
                          "${pkgs.xfstests}/bin/xfstests-check -d ${cfg.arguments}"
      '';
    };
  };
}
