{
  stdenv,
  lib,
  perl,
  gmp,
  libmpc,
  mpfr,
  bison,
  flex,
  pahole,
  buildPackages,
  rustPlatform,
  rustc,
  rustfmt,
  cargo,
  rust-bindgen,
}: {
  pkgs,
  nixpkgs,
  structuredExtraConfig,
  src,
  version,
  withRust ? false,
  enableCommonConfig ? false,
  commonStructuredConfig ? [],
  structuredConfigFromPatches ? [],
  randstructSeed ? "",
}: let
  defaultConfig = with lib.kernel; {
    DEBUG_FS = yes;
    DEBUG_KERNEL = yes;
    DEBUG_MISC = yes;
    #DEBUG_BUGVERBOSE = yes;
    DEBUG_BOOT_PARAMS = yes;
    DEBUG_STACK_USAGE = yes;
    DEBUG_SHIRQ = yes;
    DEBUG_ATOMIC_SLEEP = yes;
    DEBUG_KMEMLEAK = yes;
    DEBUG_INFO_DWARF5 = yes;
    DEBUG_INFO_COMPRESSED_NONE = yes;
    KERNEL_XZ = yes;
    FUNCTION_TRACER = yes;
    FUNCTION_GRAPH_TRACER = yes;
    FUNCTION_GRAPH_RETVAL = yes;
    FPROBE = yes;
    FUNCTION_PROFILER = yes;
    FTRACE_SYSCALLS = yes;

    LOCALVERSION_AUTO = no;

    IKCONFIG = yes;
    IKCONFIG_PROC = yes;
    # Compile with headers
    IKHEADERS = yes;

    SLUB_DEBUG = yes;
    DEBUG_MEMORY_INIT = yes;
    KASAN = yes;
    #SLUB_TINY = no;

    # FRAME_WARN - warn at build time for stack frames larger tahn this.

    MAGIC_SYSRQ = yes;

    LOCK_STAT = yes;
    PROVE_LOCKING = yes;

    FTRACE = yes;
    STACKTRACE = yes;
    IRQSOFF_TRACER = yes;

    KGDB = yes;
    UBSAN = yes;
    BUG_ON_DATA_CORRUPTION = yes;
    SCHED_STACK_END_CHECK = yes;
    UNWINDER_FRAME_POINTER = yes;
    "64BIT" = yes;

    # initramfs/initrd ssupport
    BLK_DEV_INITRD = yes;

    PRINTK = yes;
    PRINTK_TIME = yes;
    EARLY_PRINTK = yes;

    # Support elf and #! scripts
    BINFMT_ELF = yes;
    BINFMT_SCRIPT = yes;

    # Create a tmpfs/ramfs early at bootup.
    DEVTMPFS = yes;
    DEVTMPFS_MOUNT = yes;

    TTY = yes;
    SERIAL_8250 = yes;
    SERIAL_8250_CONSOLE = yes;

    PROC_FS = yes;
    SYSFS = yes;
    SYSCTL = yes;

    MODULES = yes;
    MODULE_UNLOAD = yes;

    # QEMU stuff
    VIRTIO_BLK = yes;
    VIRTIO_MENU = yes;
    VIRTIO_PCI = yes;
    VIRTIO_NET = yes;
    VIRTIO_MMIO = yes;
    VIRTIO_BALLOON = yes;
    SCSI = yes;
    SCSI_VIRTIO = yes;
    VIRTIO = yes;
    AUTOFS_FS = yes;
    EXT4_FS = yes;
    NET_9P = yes;
    NET_9P_VIRTIO = yes;
    "9P_FS" = yes;
    HW_RANDOM = yes;
    HW_RANDOM_VIRTIO = yes;
    PCI = yes;
    NET = yes;
    NETDEVICES = yes;
    NET_CORE = yes;
    INET = yes;
    OVERLAY_FS = yes;
    VIRTIO_CONSOLE = yes;
    CGROUPS = yes;
    SIGNALFD = yes;
    TIMERFD = yes;
    EPOLL = yes;
    FHANDLE = yes;
    CRYPTO_USER_API_HASH = yes;
    CRYPTO_HMAC = yes;
    CRYPTO_CRC32C = yes;
    DMI = yes;
    DMIID = yes;
    TMPFS_POSIX_ACL = yes;
    TMPFS_XATTR = yes;
    SECCOMP = yes;
    SHMEM = yes;
    SATA_NV = yes;
    SATA_VIA = yes;
    SATA_SIS = yes;
    SATA_ULI = yes;
    ATA_PIIX = yes;
    PATA_MARVELL = yes;
    SATA_AHCI = yes;
    RTC_CLASS = yes;
    #MMC_BLOCK = yes;
    ATA = yes;
    TMPFS = yes;
    UNIX = yes;
    INOTIFY_USER = yes;
    # Systemd required modules
    # boot.initrd.includeDefaultModules = false;
    BLK_DEV_NVME = yes;
    BLK_DEV_SD = yes;
    BLK_DEV_SR = yes;
    MMC = yes;
    MMC_BLOCK = yes;
    USB = yes;
    USB_PCI = yes;
    USB_SUPPORT = yes;
    USB_UHCI_HCD = yes;
    USB_EHCI_HCD = yes;
    USB_EHCI_PCI = yes;
    USB_OHCI_HCD = yes;
    USB_XHCI_PCI = yes;
    USB_XHCI_HCD = yes;
    HID_GENERIC = yes;
    HID_LENOVO = yes;
    HID_APPLE = yes;
    HID_ROCCAT = yes;
    HID_LOGITECH_HIDPP = yes;
    HIDRAW = yes;
    HID_LOGITECH = yes;
    HID_LOGITECH_DJ = yes;
    HID_MICROSOFT = yes;
    HID_CHERRY = yes;
    SERIO_PCIPS2 = yes;
    KEYBOARD_ATKBD = yes;
    SERIO_I8042 = yes;
    RTC_DRV_CMOS = yes;
    MD = yes;
    BLK_DEV_DM = yes;
    CRYPTO_SHA256 = yes;
    HID_CORSAIR = yes;
    LIBCRC32C = yes;
  };
in
  stdenv.mkDerivation
  rec {
    kernelArch = stdenv.hostPlatform.linuxArch;
    extraMakeFlags = [];

    inherit version src;

    pname = "linux-config";

    RUST_LIB_SRC = lib.optionalString withRust rustPlatform.rustLibSrc;

    # Flags that get passed to generate-config.pl
    # ignoreConfigErrors: Ignores any config errors in script (eg unused options)
    # preferBuiltin: Build modules as builtin
    preferBuiltin = false; # or false
    ignoreConfigErrors = false;
    generateConfig = "${nixpkgs}/pkgs/os-specific/linux/kernel/generate-config.pl";

    kernelConfig = passthru.moduleStructuredConfig.intermediateNixConfig;
    passAsFile = ["kernelConfig"];

    depsBuildBuild = [buildPackages.stdenv.cc];
    nativeBuildInputs =
      [perl gmp libmpc mpfr bison flex bison flex pahole]
      ++ lib.optionals withRust [rust-bindgen rustc rustfmt cargo];

    platformName = stdenv.hostPlatform.linux-kernel.name;
    # e.g. "bzImage"
    kernelTarget = stdenv.hostPlatform.linux-kernel.target;
    kernelBaseConfig = stdenv.hostPlatform.linux-kernel.baseConfig;

    makeFlags =
      lib.optionals (stdenv.hostPlatform.linux-kernel ? makeFlags)
      stdenv.hostPlatform.linux-kernel.makeFlags;

    postPatch = ''
      # Ensure that depmod gets resolved through PATH
      sed -i Makefile -e 's|= /sbin/depmod|= depmod|'

      # Don't include a (random) NT_GNU_BUILD_ID, to make the build more deterministic.
      # This way kernels can be bit-by-bit reproducible depending on settings
      # (e.g. MODULE_SIG and SECURITY_LOCKDOWN_LSM need to be disabled).
      # See also https://kernelnewbies.org/BuildId
      sed -i Makefile -e 's|--build-id=[^ ]*|--build-id=none|'

      # Some linux-hardened patches now remove certain files in the scripts directory, so the file may not exist.
      [[ -f scripts/ld-version.sh ]] && patchShebangs scripts/ld-version.sh

      # Set randstruct seed to a deterministic but diversified value. Note:
      # we could have instead patched gen-random-seed.sh to take input from
      # the buildFlags, but that would require also patching the kernel's
      # toplevel Makefile to add a variable export. This would be likely to
      # cause future patch conflicts.
      for file in scripts/gen-randstruct-seed.sh scripts/gcc-plugins/gen-random-seed.sh; do
        if [ -f "$file" ]; then
          substituteInPlace "$file" \
            --replace NIXOS_RANDSTRUCT_SEED \
            $(echo ${randstructSeed}${src} ${placeholder "configfile"} | sha256sum | cut -d ' ' -f 1 | tr -d '\n')
          break
        fi
      done

      patchShebangs scripts

      # also patch arch-specific install scripts
      for i in $(find arch -name install.sh); do
          patchShebangs "$i"
      done

      # Patch kconfig to print "###" after every question so that
      # generate-config.pl from the generic builder can answer them.
      sed -e '/fflush(stdout);/i\printf("###");' -i scripts/kconfig/conf.c
    '';

    preUnpack = "";

    buildPhase = ''
      export buildRoot="''${buildRoot:-build}"
      export HOSTCC=$CC_FOR_BUILD
      export HOSTCXX=$CXX_FOR_BUILD
      export HOSTAR=$AR_FOR_BUILD
      export HOSTLD=$LD_FOR_BUILD

      # Get a basic config file for later refinement with $generateConfig.
      make $makeFlags \
          -C . O="$buildRoot" $kernelBaseConfig \
          ARCH=$kernelArch \
          HOSTCC=$HOSTCC HOSTCXX=$HOSTCXX HOSTAR=$HOSTAR HOSTLD=$HOSTLD \
          CC=$CC OBJCOPY=$OBJCOPY OBJDUMP=$OBJDUMP READELF=$READELF \
          $makeFlags

      # Create the config file.
      echo "generating kernel configuration..."
      ln -s "$kernelConfigPath" "$buildRoot/kernel-config"
      DEBUG=1 ARCH=$kernelArch KERNEL_CONFIG="$buildRoot/kernel-config" \
        PREFER_BUILTIN=$preferBuiltin BUILD_ROOT="$buildRoot" SRC=. MAKE_FLAGS="$makeFlags" \
        perl -w $generateConfig
    '';

    installPhase = "mv $buildRoot/.config $out";

    enableParallelBuilding = true;

    passthru = rec {
      module = import "${nixpkgs}/nixos/modules/system/boot/kernel_config.nix";
      # used also in apache
      # { modules = [ { options = res.options; config = svc.config or svc; } ];
      #   check = false;
      # The result is a set of two attributes
      moduleStructuredConfig =
        (lib.evalModules {
          modules =
            [
              module
            ]
            ++ lib.optionals enableCommonConfig [
              {
                settings = commonStructuredConfig;
                _file = "pkgs/os-specific/linux/kernel/common-config.nix";
              }
            ]
            ++ [
              {
                settings = structuredExtraConfig // defaultConfig;
                _file = "structuredExtraConfig";
              }
            ]
            ++ structuredConfigFromPatches;
        })
        .config;

      structuredConfig = moduleStructuredConfig.settings;
    };
  }
