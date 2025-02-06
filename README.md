# Development shell for Linux Kernel

Development environment for Linux kernel.

In development, everything changing :)

NixOS/Nix and direnv is necessary.

## Usage

Create direnv environment:

```
echo "use flake github:alberand/nix-kernel-vm" > .envrc
```

Active the environment:

```
direnv allow
```

Now you should have following commands:

```
# Generate minimal kernel config
vmtest-config

# Build VM (based on QEMU)
vmtest-build

# Build the same system but into ISO image
vmtest-build-iso

# Run VM
vmtest-run
```

For more flexibility you can create flake and overwrite kernel source,
kernel config, xfsprogs, xfstests, xfstests suite to run.

```
nix flake init --template "github:alberand/nix-kernel-vm#x86_64-linux.kernel-dev"
```
