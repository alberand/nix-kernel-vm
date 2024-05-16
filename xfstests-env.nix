{
  nixpkgs,
  pkgs,
}:
{
  privateNetwork = true;
  hostAddress = "10.233.1.1";
  localAddress = "10.233.1.2";
  # Container's mount
  bindMounts = {
    "." = {
      hostPath = "/root/xfstests-dev";
      isReadOnly = false;
    };
  };
}
// nixpkgs.lib.nixosSystem {
  inherit pkgs;
  modules = [
    ({pkgs, ...}: {
      boot.isContainer = true;
      networking.hostName = "xfstests";

      systemd.tmpfiles.rules = [
        "d /root/xfstests-dev 0700 root root"
      ];

      environment.systemPackages = with pkgs; [
        vim
        xfstests
      ];

      system.stateVersion = "23.11";
    })
  ];
}
