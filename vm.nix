{
  sharedir,
  qemu-options ? [],
  ...
}: {
  virtualisation = {
    diskSize = 20000; # MB
    # Store the image in sharedir instead of pwd
    diskImage = "${sharedir}/test-node.qcow2";
    memorySize = 4096; # MB
    cores = 4;
    writableStoreUseTmpfs = false;
    useDefaultFilesystems = true;
    # Run qemu in the terminal not in Qemu GUI
    graphics = false;

    qemu = {
      # Network requires tap0 netowrk on the host
      options =
        [
          "-device e1000,netdev=network0,mac=00:00:00:00:00:00"
          "-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"
          "-device virtio-rng-pci"
        ]
        ++ qemu-options;
    };

    sharedDirectories = {
      results = {
        source = "${sharedir}/results";
        target = "/root/results";
      };
      vmtest = {
        source = "${sharedir}";
        target = "/root/vmtest";
      };
    };
  };
}
