{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.programs.simple-test;
in {
  options.programs.simple-test = {
    enable = mkEnableOption {
      name = "simple-test";
      default = true;
      example = true;
    };

    arguments = mkOption {
      description = "arguments to the test script";
      default = "";
      example = "-f hello";
      type = types.str;
    };

    test-dev = mkOption {
      description = "Path to disk used as TEST_DEV";
      default = "/dev/sda";
      example = "/dev/sda";
      type = types.str;
    };

    sharedir = mkOption {
      description = "path to the share directory inside VM";
      default = "/root/vmtest";
      example = "/root/vmtest";
      type = types.str;
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

    mkfs-cmd = mkOption {
      description = "mkfs command to recreate the disks before tests";
      default = "${pkgs.xfsprogs}/bin/mkfs.xfs";
      example = "${pkgs.xfsprogs}/bin/mkfs.xfs";
      type = types.str;
    };

    mkfs-opt = mkOption {
      description = "Options for mkfs-cmd";
      default = "-f";
      example = "-f";
      type = types.str;
    };
  };

  config = mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /mnt 1777 root root"
      "d /mnt/test 1777 root root"
    ];

    systemd.services.simple-test = {
      enable = true;
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "tty";
        StandardError = "tty";
        # argh... Nix ignore SIGPIPE somewhere and it causes all child processes
        # to ignore SIGPIPE. Don't remove it or otherwise many tests will fail
        # due too Broken pipe. Test with yes | head should not return Brokne
        # pipe.
        IgnoreSIGPIPE = "no";
        User = "root";
        Group = "root";
        WorkingDirectory = "/root";
      };
      after = [ "network.target" "network-online.target" "local-fs.target" ];
      wants = [ "network.target" "network-online.target" "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      postStop = ''
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

        if ${pkgs.util-linux}/bin/mountpoint /mnt/test; then
          ${pkgs.util-linux}/bin/umount ${cfg.test-dev}
        fi
        ${cfg.mkfs-cmd} ${cfg.mkfs-opt} -L test ${cfg.test-dev}

        chmod u+x ${cfg.sharedir}/test.sh
        ${pkgs.bash}/bin/bash -l -c 'exec ${cfg.sharedir}/test.sh'
        exit $?
      '';
    };
  };
}
