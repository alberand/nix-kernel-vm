#!/usr/bin/env bash

ROOT=@root@
VERBOSE=0
WORKDIR="$HOME/.vmtest/$PNAME"
mkdir -p "$WORKDIR"

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
	#nix build "$ROOT#$PNAME.kconfig"
	cp "$ROOT/kconfig/config-v6.13" .config
	chmod 644 .config
}

function build {
	# TODO this should be in workdir
	pushd "$WORKDIR"
	nix flake init --template "github:alberand/nix-kernel-vm#x86_64-linux.vm"
	popd

	# TODO this should be in workdir
	local config="$(pwd)/.vmtest.toml"
	echo "Using config $config"
	if [ -f "$config" ]; then
		local xfstestsrev=$(tq -f "$config" 'xfstests.rev')
		local xfsprogsrev=$(tq -f "$config" 'xfsprogs.rev')
		XFSTESTS=""
		if [ "$xfstestsrev" != "" ]; then
IFS='' read -r -d '' XFSTESTS <<EOF
	programs.xfstests.src = $(nurl git@github.com:alberand/xfstests.git $xfstestsrev);
EOF
		fi
		XFSPROGS=""
		if [ "$xfsprogsrev" != "" ]; then
IFS='' read -r -d '' XFSPROGS <<EOF
	programs.xfsprogs.src = $(nurl git@github.com:alberand/xfsprogs.git $xfsprogsrev);
EOF
		fi
		cat << EOF > "$WORKDIR/sources.nix"
{pkgs, ...}: with pkgs; {
$XFSTESTS
$XFSPROGS
}
EOF
		nixfmt "$WORKDIR/sources.nix"
	fi

	if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
		cp "$HOME/.ssh/id_rsa.pub" "$WORKDIR/ssh-key.pub"
	else
		ssh-agent sh -c 'ssh-add; ssh-add -L' > "$WORKDIR/ssh-key.pub"
	fi

	case $1 in
	  vm)
	    shift
		nix build "$WORKDIR#vm"
	    ;;
	  iso)
	    shift
		nix build "$WORKDIR#iso"
	    ;;
	  *)
		usage
	    ;;
	esac
}

function run {
	nix run "$WORKDIR#vm"
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
