#!/usr/bin/env bash

ROOT=@root@
VERBOSE=0

usage() {
    cat << FFF
Usage: ${0##*/} COMMAND [OPTIONS]

Description: Build, test and deploy linux kernel system

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output

Commands:
    config          Generate minimal working kernel configuration .config
    build           Build virtual machine or ISO image
    run             Run virtual machine
    deploy          Deploy ISO image to the Libvirt host

Example:
    $ ${0##*/} config
    $ make -j$(nproc)
    $ ${0##*/} build vm
    $ cat << EOF > .vmtest.toml
[kernel]
kernel = "arch/x86_64/boot/bzImage"
EOF
    $ ${0##*/} run vm
FFF
    exit 1
}

function config {
	nix build "$ROOT#$PNAME.kconfig"
}

function build {
case $1 in
  vm)
    shift
	nix build "$ROOT#$PNAME.vm"
    ;;
  iso)
    shift
	nix build "$ROOT#$PNAME.iso"
    ;;
  *)
	usage
    ;;
esac
}

function run {
	nix run "$ROOT#$PNAME.vm"
}

function deploy {
	vmtest-deploy $@
}

case $1 in
  config)
    shift
    config $@
    ;;
  build)
    shift
    build $@
    ;;
  run)
    shift
    run $@
    ;;
  deploy)
    shift
    deploy $@
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  -v|--verbose)
    VERBOSE=1
    ;;
  -*|--*)
    echo "Unknown option $1"
    usage
    exit 1
    ;;
  *)
	usage
    ;;
esac

# vim: set filetype=bash :
