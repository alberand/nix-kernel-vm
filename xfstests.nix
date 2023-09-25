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

    sharedir = mkOption {
      description = "path to the share directory inside VM";
      default = "";
      example = "/root/vmtest";
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

    pre-test-hook = mkOption {
      description = "bash script run before test execution";
      default = "";
      example = "trace-cmd start -e xfs";
      type = types.str;
    };

    post-test-hook = mkOption {
      description = "bash script run after test execution";
      default = "";
      example = "trace-cmd stop; trace-cmd show > /root/trace.log";
      type = types.str;
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
          # Don't know why but "bin" should not be here as it create dependency
          # cycle
          outputs = [ "bin" "dev" "out" "doc" ];

          patches = (o.patches or [ ]) ++ [
            ./0001-fix-nix-make-doesn-t-have-enough-permission-to-chang.patch
          ];
          # We need to add autoconf tools because nixpgs does it automatically
          # somewhere inside
          nativeBuildInputs = prev.xfsprogs.nativeBuildInputs ++ [
            pkgs.libtool
            pkgs.autoconf
            pkgs.automake
          ];
          preConfigure = ''
            for file in scrub/{xfs_scrub_all.cron.in,xfs_scrub@.service.in,xfs_scrub_all.service.in}; do
              substituteInPlace "$file" \
                --replace '@sbindir@' '/run/current-system/sw/bin'
            done
            make configure
            patchShebangs ./install-sh
          '';
        });
      })
    ];

    environment.systemPackages = with pkgs; [
      xfsprogs
    ];

    # Setup envirionment
    environment.variables.HOST_OPTIONS = pkgs.writeText "xfstests.config"
      (builtins.readFile cfg.testconfig);

    users.users.fsgqa = {
      isNormalUser  = true;
      description  = "Test user";
      group = "fsgqa2";
    };

    users.users.fsgqa2 = {
      isNormalUser  = true;
      description  = "Test user";
      group = "fsgqa2";
    };

    users.users.fsgqa-123456 = {
      isNormalUser  = true;
      description  = "Test user";
      group = "fsgqa-123456";
    };

    users.groups.fsgqa.members = [ "fsgqa" ];
    users.groups.fsgqa2.members = [ "fsgqa2" ];
    users.groups.fsgqa-123456.members = [ "fsgqa-123456" ];

    systemd.tmpfiles.rules = [
      "d /mnt 1777 root root"
      "d /mnt/test 1777 root root"
      "d /mnt/scratch 1777 root root"
    ];

    fileSystems."/mnt/test" = {
      device = "/dev/vda";
      fsType = "xfs";
      autoFormat = true;
      label = "test";
    };

    fileSystems."/mnt/scratch" = {
      device = "/dev/vdb";
      fsType = "xfs";
      autoFormat = true;
      label = "scratch";
    };

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
      postStart = ''
                  ${cfg.post-test-hook}
                  # Beep beep... Human... back to work
                  echo -ne '\007'

                  # Unload kernel module if we are in VM
                  if [ -d ${cfg.sharedir}/modules ]; then
                    # Handle case when there's no modules glob -> empty
                    shopt -s nullglob
                    for module in ${cfg.sharedir}/modules/*.ko; do
                            if cat /proc/modules | grep -c "$module"; then
                              ${pkgs.kmod}/bin/rmmod $module;
                            fi
                    done;
                  fi
      '' + optionalString cfg.autoshutdown ''
                  # Auto poweroff
                  ${pkgs.systemd}/bin/systemctl poweroff;
      '';
      script = ''
                  ${cfg.pre-test-hook}

                  # Handle case when there's no modules glob -> empty
                  if [ -d ${cfg.sharedir}/modules ]; then
                    shopt -s nullglob
                    for module in ${cfg.sharedir}/modules/*.ko; do
                        ${pkgs.kmod}/bin/insmod $module;
                    done;
                  fi

                  arguments=""
                  if [ -f ${cfg.sharedir}/totest ]; then
                    arguments="$(cat ${cfg.sharedir}/totest)"
                  else
                    arguments="${cfg.arguments}"
                  fi

                  # User wants to run shell script instead of fstests
                  # TODO create a separate service for this
                  if [[ -f ${cfg.sharedir}/test.sh ]]; then
                    chmod u+x ${cfg.sharedir}/test.sh
                    ${pkgs.bash}/bin/bash ${cfg.sharedir}/test.sh
                    exit $?
                  else
                    ${pkgs.bash}/bin/bash -lc \
                      "${pkgs.xfstests}/bin/xfstests-check -d $arguments"
                  fi
      '';
    };
  };
}
