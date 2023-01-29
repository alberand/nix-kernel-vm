export PATH="$coreutils/bin"
mkdir $out
cat << EOF > $out/local.config
export TEST_DEV=/dev/vdb
export TEST_DIR=/mnt/test
export SCRATCH_DEV=/dev/vdc
export SCRATCH_MNT=/mnt/scratch
EOF
