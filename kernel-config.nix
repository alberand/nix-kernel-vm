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
}: {
  kconfig,
  src,
  version,
}: let
  defaultConfig = with lib.kernel; {
    # Kernel BUG()s on detected corruption of in memory data
    BUG_ON_DATA_CORRUPTION = yes;
    # When call to schedule() check stack and in case of overflow panic()
    SCHED_STACK_END_CHECK = yes;
    # The thing which shows stack trace (degrade performance by 10%)
    UNWINDER_FRAME_POINTER = yes;

    # Support kernel compressed with X
    KERNEL_GLIB = yes;
    # Don't attach -dirty version (We won't be able to boot other kernel)
    LOCALVERSION_AUTO = no;

    # Save kernel config in the kernel (also enable /proc/config.gz)
    IKCONFIG = yes;
    IKCONFIG_PROC = yes;

    # Same as IKCONFIG but for headers in /sys/kernel/kheaders.tar.xz)
    IKHEADERS = yes;

    # 64bit kernel
    "64BIT" = yes;

    # initramfs/initrd support
    BLK_DEV_INITRD = yes;

    # Support of printk
    PRINTK = yes;
    PRINTK_TIME = yes;
    # Write printk to VGA/serial port
    EARLY_PRINTK = yes;
    EARLY_PRINTK_DBGP = yes;
    EARLY_PRINTK_USB_XDBC = yes;

    # Support elf and #! scripts
    BINFMT_ELF = yes;
    BINFMT_SCRIPT = yes;

    # Create a tmpfs/ramfs early at bootup.
    DEVTMPFS = yes;
    DEVTMPFS_MOUNT = yes;

    # Console
    TTY = yes;
    SERIAL_8250 = yes;
    SERIAL_8250_CONSOLE = yes;
    SERIAL_DEV_BUS = yes; # enables support for serial devices
    SERIAL_DEV_CTRL_TTYPORT = yes; # enables support for TTY serial devices

    # Required by profiles/qemu
    NET_9P_VIRTIO = yes;
    "9P_FS" = yes;
    BLK_DEV = yes;
    NETWORK_FILESYSTEMS = yes;

    # /proc
    PROC_FS = yes;
    # /sys
    SYSFS = yes;
    # /proc/sys
    SYSCTL = yes;

    # Can kernel load modules?
    MODULES = yes;
    MODULE_FORCE_LOAD = yes;
    MODULE_UNLOAD = yes;

    # No graphics
    DRM = no;
    DRM_I915 = no;

    # No sound
    SOUND = no;

    # QEMU stuff
    VIRTIO = yes;
    VIRTIO_BLK = yes;
    VIRTIO_MENU = yes;
    VIRTIO_PCI = yes;
    VIRTIO_NET = yes;
    VIRTIO_MMIO = yes;
    VIRTIO_BALLOON = yes;
    VIRTIO_CONSOLE = yes;
    SCSI_VIRTIO = yes;
    HW_RANDOM_VIRTIO = yes;

    # Hard disks protocol
    SCSI = yes;
    BLK_DEV_SD = yes;
    ATA = yes;
    SATA_NV = no;
    SATA_VIA = no;
    SATA_SIS = no;
    SATA_ULI = no;
    ATA_PIIX = no;
    SATA_AHCI = no;
    PATA_MARVELL = no;
    MMC = no;
    MMC_BLOCK = no;

    # Basic functionality
    HW_RANDOM = yes;
    PCI = yes;
    NET = yes;
    NETDEVICES = yes;
    NET_CORE = yes;
    INET = yes;
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
    RTC_CLASS = yes;
    UNIX = yes;
    INOTIFY_USER = yes;

    # Filesystems
    EXT4_FS = yes;
    TMPFS = yes;
    OVERLAY_FS = yes;

    # NVME
    NVME_CORE = no;
    BLK_DEV_NVME = no;

    # Systemd required modules
    # boot.initrd.includeDefaultModules = false;
    USB = yes;
    USB_PCI = yes;
    USB_SUPPORT = yes;
    USB_UHCI_HCD = no;
    USB_EHCI_HCD = no;
    USB_EHCI_PCI = no;
    USB_OHCI_HCD = no;
    USB_XHCI_PCI = no;
    USB_XHCI_HCD = no;
    HID_GENERIC = yes;
    HIDRAW = yes;
    HID_LENOVO = no;
    HID_APPLE = no;
    HID_ROCCAT = no;
    HID_LOGITECH_HIDPP = no;
    HID_LOGITECH = no;
    HID_LOGITECH_DJ = no;
    HID_MICROSOFT = no;
    HID_CHERRY = no;
    HID_CORSAIR = no;
    SERIO_PCIPS2 = yes;
    KEYBOARD_ATKBD = yes;
    SERIO_I8042 = yes;
    RTC_DRV_CMOS = yes;
    MD = yes;
    BLK_DEV_DM = yes;
    CRYPTO_SHA256 = yes;
    LIBCRC32C = yes;

    # Debug
    DEBUG_FS = yes;
    DEBUG_KERNEL = yes;
    DEBUG_MISC = yes;
    DEBUG_BOOT_PARAMS = yes;
    DEBUG_STACK_USAGE = yes;
    DEBUG_SHIRQ = yes;
    DEBUG_ATOMIC_SLEEP = yes;
    DEBUG_KMEMLEAK = yes;
    DEBUG_INFO_DWARF5 = yes;
    DEBUG_INFO_COMPRESSED_NONE = yes;
    DEBUG_VM = yes;
    FUNCTION_TRACER = yes;
    FUNCTION_GRAPH_TRACER = yes;
    FUNCTION_GRAPH_RETVAL = yes;
    FPROBE = yes;
    FUNCTION_PROFILER = yes;
    FTRACE_SYSCALLS = yes;
    KEXEC = yes;
    SLUB_DEBUG = no;
    DEBUG_MEMORY_INIT = yes;
    KASAN = no;
    # Sending special commands with SysRq key (ALT+PrintScreen)
    MAGIC_SYSRQ = yes;
    # Lock usage statistics
    LOCK_STAT = yes;
    # Mathematically calculate and then report deadlocks before they occures
    PROVE_LOCKING = yes;
    # Enable kernel tracers
    FTRACE = yes;
    # Creates /proc/pid/stack which shows current stack for each process
    STACKTRACE = yes;
    # Max time spent in interrupt critical section
    IRQSOFF_TRACER = no;
    # Kernel debugger
    KGDB = no;
    # Detector of undefined behavior, in runtime
    UBSAN = no;

    # ISO
    SQUASHFS = yes;
    SQUASHFS_XZ = yes;
    SQUASHFS_ZSTD = yes;
    ISO9660_FS = yes;
    USB_UAS = module;
    BLK_DEV_LOOP = yes;
    CRYPTO_ZSTD = yes;
    INITRAMFS_COMPRESSION_ZSTD = yes;

    # other
    NET_9P = yes;
    VT = yes;
    UNIX98_PTYS = yes;
    SCSI_LOWLEVEL = yes;
    WATCHDOG = yes;
    WATCHDOG_CORE = yes;
    I6300ESB_WDT = yes;
    DAX = yes;
    DAX_DRIVER = yes;
    FS_DAX = yes;
    MEMORY_HOTPLUG = yes;
    MEMORY_HOTREMOVE = yes;
    ZONE_DEVICE = yes;
    FUFE_FS = yes;
    VIRTIO_FS = yes;
  };
in
  stdenv.mkDerivation rec {
    inherit version src;
    pname = "linux-config";

    generateConfig = ./generate-config.pl;

    kernelConfig = passthru.moduleStructuredConfig.intermediateNixConfig;
    passAsFile = ["kernelConfig"];

    depsBuildBuild = [buildPackages.stdenv.cc];
    nativeBuildInputs = [perl gmp libmpc mpfr bison flex bison flex pahole];

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
      for file in scripts/gen-randstruct-seed.sh; do
        if [ -f "$file" ]; then
          substituteInPlace "$file" \
            --replace NIXOS_RANDSTRUCT_SEED \
            $(echo ${src} ${placeholder "configfile"} | sha256sum | cut -d ' ' -f 1 | tr -d '\n')
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

    buildPhase = ''
      export buildRoot="''${buildRoot:-build}"
      export HOSTCC=$CC_FOR_BUILD
      export HOSTCXX=$CXX_FOR_BUILD
      export HOSTAR=$AR_FOR_BUILD
      export HOSTLD=$LD_FOR_BUILD

      # Get a basic config file for later refinement with $generateConfig.
      echo "Generating 'olddefconfig' config"
      make $makeFlags \
          -C . \
          O="$buildRoot" \
          ARCH=x86_64 \
          HOSTCC=$HOSTCC \
          HOSTCXX=$HOSTCXX \
          HOSTAR=$HOSTAR \
          HOSTLD=$HOSTLD \
          CC=$CC \
          OBJCOPY=$OBJCOPY \
          OBJDUMP=$OBJDUMP \
          READELF=$READELF \
          $makeFlags \
          olddefconfig

      # Create the config file.
      echo "Generating kernel configuration"
      ln -s "$kernelConfigPath" "$buildRoot/kernel-config"
      DEBUG=1 \
        ARCH=x86_64 \
        KERNEL_CONFIG="$buildRoot/kernel-config" \
        PREFER_BUILTIN=false \
        BUILD_ROOT="$buildRoot" \
        SRC=. \
        MAKE_FLAGS="$makeFlags" \
        perl -w $generateConfig
    '';

    installPhase = "mv $buildRoot/.config $out";

    enableParallelBuilding = true;

    passthru = rec {
      # The result is a set of two attributes
      moduleStructuredConfig =
        (lib.evalModules {
          modules =
            [
              (import ./kernel_config.nix)
              {
                settings = kconfig // defaultConfig;
                _file = "structuredExtraConfig";
              }
            ];
        })
        .config;

      structuredConfig = moduleStructuredConfig.settings;
    };
  }
