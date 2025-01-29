#!/usr/bin/env sh
#
# Specify two variables:
#	TEST_HOST - remove/local host with virsh (/system access is needed)
#	NODE_NAME - name to identify machine to be deployed

function help() {
    echo "$(basename $0) <path to iso>" 1>&2
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

if [ -z "$TEST_HOST" ]; then
    echo '$TEST_HOST is not defined' 1>&2
    exit 1
fi

if [ -z "$NODE_NAME" ]; then
    echo '$NODE_NAME is not defined' 1>&2
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Required path to image is missing"
    help
fi

TEST_ISO="$1"
PREFIX="aalbersh"
SYSURI="qemu+ssh://$TEST_HOST/system"
NODE="$PREFIX-$NODE_NAME"
TEST_SYSTEM_XML="$NODE.xml"

if ! virsh --connect $SYSURI version; then
    echo "Not able to connect to $SYSURI. Is your user in 'libvirt' group?"
    exit 1
fi

state=$(virsh --connect $SYSURI list --all | grep " $NODE " | awk '{ print $3}')
if [ "$state" != "" ]; then
	remove_node $SYSURI $NODE
fi

echo "Creating volumes for new '$NODE'"
virsh --connect $SYSURI vol-list --pool default | grep -q "$NODE-test"
if [ $? -eq 0 ]; then
	virsh --connect $SYSURI \
		vol-wipe \
		--pool default \
		$NODE-test
else
	virsh --connect $SYSURI \
		vol-create-as \
		--pool default \
		--name $NODE-test \
		--capacity 20G \
		--format qcow2
fi;

virsh --connect $SYSURI vol-list --pool default | grep -q "$NODE-scratch"
if [ $? -eq 0 ]; then
	virsh --connect $SYSURI \
		vol-wipe \
		--pool default \
		$NODE-scratch
else
	virsh --connect $SYSURI \
		vol-clone \
		--pool default \
		$NODE-test \
		$NODE-scratch
fi;

echo "Uploading '$TEST_ISO' to '$TEST_HOST:/tmp/$NODE.iso'"
rsync -avz -P \
       $TEST_ISO \
       $TEST_HOST:/tmp/$NODE.iso
if [ $? -ne 0 ]; then
	exit 1;
fi;

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

echo "Open console with:"
echo "\tvirsh --connect $SYSURI console $NODE"
