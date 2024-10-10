#!/usr/bin/env sh
#
# Specify two variables:
#	TEST_HOST - remove/local host with virsh (/system access is needed)
#	NODE_NAME - name to identify machine to be deployed

function help() {
    echo "$(basename $0) <unique name> <path to iso>" 1>&2
    exit 0
}

function remove_node() {
	uri="$1"
	node="$2"
	echo "Stopping '$node' node"
	virsh --connect $sysuri \
		shutdown \
		$node
	virsh --connect $sysuri \
		undefine \
		$node

	echo "Removing '$node's volumes"
	virsh --connect $sysuri \
		vol-delete \
		--pool default \
		$node-test
	virsh --connect $sysuri \
		vol-delete \
		--pool default \
		$node-scratch
}

if [[ -z "$TEST_HOST" ]]; then
    echo '$TEST_HOST is not defined' 1>&2
    exit 1
fi

if [[ -z "$NODE_NAME" ]]; then
	if [ "$#" -ne 2 ]; then
		echo '$NODE_NAME is not defined. Use first argument' 1>&2
		help
	fi
fi

TEST_HOST=$TEST_HOST
NODE_NAME="$1"
TEST_ISO="$2"
PREFIX="aalbersh"
TEST_SYSTEM_XML="$PREFIX-$NODE_NAME.xml"

SYSURI="qemu+ssh://$TEST_HOST/system"
NODE="$NODE"

if ! virsh --connect $SYSURI version; then
    echo "Not able to connect to $SYSURI. Is your user in 'libvirt' group?"
    exit 1
fi

# Cleaning
ssh -t $TEST_HOST "sudo rm -rf /tmp/$NODE.iso"

state=$(virsh --connect $SYSURI list --all | grep " $NODE " | awk '{ print $3}')
if [ "$state" != "" ]; then
	remote_node $SYSURI $NODE
fi

echo "Creating volumes for new '$NODE'"
virsh --connect $SYSURI \
	vol-create-as \
	--pool default \
	--name $NODE-test \
	--capacity 20G \
	--format qcow2
virsh --connect $SYSURI \
	vol-clone \
	--pool default \
	$NODE-test \
	$NODE-scratch \

echo "Uploading ISO"
rsync -avz -I -P --ignore-existing \
       $TEST_ISO \
       $TEST_HOST:/tmp/$NODE.iso

echo "Bringing up the node"
virt-install --connect $SYSURI \
	--name "$NODE" \
	--hvm \
	--osinfo "nixos-unstable" \
	--memory=8000 \
	--vcpu 4 \
	--disk vol=default/$NODE-test,target.bus=sata \
	--disk vol=default/$NODE-scratch,target.bus=sata \
	--network network=default \
	--cdrom "/tmp/$NODE.iso" \
	--serial pty \
	--graphics none \
	--noautoconsole \
	--transient
