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
      name = "xfstests service";
      default = true;
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
                  # Handle case when there's no modules glob -> empty
                  shopt -s nullglob
                  for module in /root/vmtest/modules/*.ko; do
                          if cat /proc/modules | grep -c "$module"; then
                            ${pkgs.kmod}/bin/rmmod $module;
                          fi
                  done;
                  # Auto poweroff
                  # ${pkgs.systemd}/bin/systemctl poweroff;
      '';
      script = ''
                  # User wants to run shell script instead of fstests
                  if [[ -f /root/vmtest/test.sh ]]; then
                    chmod u+x /root/vmtest/test.sh
                    ${pkgs.bash}/bin/bash /root/vmtest/test.sh
                    exit $?
                  fi

                  # Handle case when there's no modules glob -> empty
                  shopt -s nullglob
                  for module in /root/vmtest/modules/*.ko; do
                          ${pkgs.kmod}/bin/insmod $module;
                  done;

                  ${pkgs.bash}/bin/bash -lc \
                          "${pkgs.xfstests}/bin/xfstests-check -d $(cat /root/vmtest/totest)"
      '';
    };
  };
}
