# Development shell for Linux Kernel

## Usage

Add this to your ./linux directory:

```
{
  description = "Linux Kernel development env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-kernel-vm.url = "github:alberand/nix-kernel-vm";
  };

  outputs = { self, nixpkgs, flake-utils, nix-kernel-vm }:
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { inherit system; };
    root = builtins.toString ./.;
  in rec {
    devShells.default = nix-kernel-vm.lib.mkLinuxShell {
      inherit pkgs;
      root = root;
      xfstests-src = fetchGit /home/alberand/Projects/xfstests-dev;

      xfsprogs-src = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfsprogs";
        rev = "91bf9d98df8b50c56c9c297c0072a43b0ee02841";
        sha256 = "sha256-otEJr4PTXjX0AK3c5T6loLeX3X+BRBvCuDKyYcY9MQ4=";
      };
    };
  });
}
```

Then, create direnv rule in ./linux directory:

```
echo "use flake . --impure" > .envrc
```

And enable direnv with `direnv allow`.

That it. Now entering this directory direnv will activate nix-shell configured
by the flake.nix. In this shell you have all dependencies to compile the kernel
and `vmtest` application.

`vmtest` is virtual machine which will take your compiled kernel and run
`xfstests` against it. You need to create `.vmtest` configuration or specify
parameters with command line options. See `vmtest --help`.
