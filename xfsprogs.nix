{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.programs.xfsprogs;
  xfsprogs-overlay = {
    version,
    src,
  }: final: prev: {
    xfsprogs = prev.xfsprogs.overrideAttrs (_old: {
      inherit version src;

      # Don't know why but "bin" should not be here as it create dependency
      # cycle
      outputs = ["bin" "dev" "out" "doc"];

      patchPhase = ''
        substituteInPlace Makefile \
          --replace "cp include/install-sh ." "cp -f include/install-sh ."
      '';
      # We need to add autoconf tools because nixpgs does it automatically
      # somewhere inside
      nativeBuildInputs =
        prev.xfsprogs.nativeBuildInputs
        ++ [
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
  };
in {
  options.programs.xfsprogs = {
    enable = mkEnableOption {
      name = "xfsprogs";
      default = false;
      example = true;
    };

    src = mkOption {
      type = types.package;
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      (xfsprogs-overlay {
        inherit (cfg) src;
        version = "git";
      })
    ];

    environment.systemPackages = with pkgs; [
      xfsprogs
    ];
  };
}
