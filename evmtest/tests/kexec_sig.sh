#!/bin/bash
# Author: David Jacobson <davidj@linux.ibm.com>
TEST="kexec_sig"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh
VERBOSE=0
POLICY_LOAD="$ROOT"/files/load_policy.sh

# This test validates that IMA measures and appraises signatures on kernel
# images when trying to kexec, if the current policy requires that.
usage() {
	echo ""
	echo "kexec_sig -k <key> [-i <kernel_image]"
	echo "	[-vh]"
	echo ""
	echo "	This test must be run as root"
	echo ""
	echo "	This test validates that IMA prevents kexec-ing to an"
	echo "	unsigned kernel image."
	echo ""
	echo ""
	echo "	-k	The key for the certificate on the IMA keyring"
	echo "	-i	An unsigned kernel image"
	echo "	-h	Display this help message"
	echo "	-v	Verbose logging"
	echo ""
	echo "	Note: kexec may require PECOFF signature"
}

parse_args () {
	TEMP=$(getopt -o 'k:i:hv' -n 'kexec_sig' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
			-h) usage; exit 0 ; shift;;
			-i) KERNEL_IMAGE=$2; shift 2;;
			-k) IMA_KEY=$2; shift 2;;
			-v) VERBOSE=1; shift;;
			--) shift; break;;
			*) echo "[*] Unrecognized option $1"; exit 1;;
		esac
	done

	if [ -z "$IMA_KEY" ]; then
		usage
		exit 1
	else
		if [ ! -e "$IMA_KEY" ]; then
			fail "Please provide valid keys"
		fi
	fi
}



# If the user doesn't provide a kernel image for kexec, get the current
get_image () {
	if [ -z "$KERNEL_IMAGE" ]; then
		v_out "No kernel provided, looking for running kernel"
		RUNNING_KERNEL=$(uname -r)
		if [ -e /boot/vmlinuz-"$RUNNING_KERNEL" ]; then
			KERNEL_IMAGE=/boot/vmlinuz-"$RUNNING_KERNEL"
			TEMP_LOCATION=$(mktemp)
			v_out "Copying kernel ($KERNEL_IMAGE) to $TEMP_LOCATION"
			cp "$KERNEL_IMAGE" "$TEMP_LOCATION"
			KERNEL_IMAGE="$TEMP_LOCATION"
		fi
	else
		if [ ! -e "$KERNEL_IMAGE" ]; then
			fail "Kernel image not found..."
		else
			v_out "Valid Kernel provided, continuing"
		fi
	fi
}

write_hash () {
	v_out "Writing file hash on kernel image"
	evmctl ima_hash -a sha256 -f "$KERNEL_IMAGE"
}

load_policy () {
	v_out "Attempting to sign policy..."
	evmctl ima_sign -f "$ROOT"/files/policies/kexec_policy -k "$IMA_KEY"

	v_out "Loading kexec policy..."
	if ! "$POLICY_LOAD" kexec_policy &>> /dev/null; then
		fail "Could not update policy - verify keys"
	fi
}

check_unsigned_KEXEC_FILE_LOAD () {
	v_out "Testing loading an unsigned kernel image using KEXEC_FILE_LOAD"\
		"syscall"
	# -s uses the kexec_file_load syscall
	if ! kexec -s -l "$KERNEL_IMAGE" &>> /dev/null; then
		v_out "Correctly prevented kexec of an unsigned image"
	else
		kexec -s -u
		fail "kexec loaded instead of rejecting. Unloading and exiting."
	fi
}

check_unsigned_KEXEC_LOAD () {
	v_out "Testing loading an unsigned kernel image using KEXEC_LOAD"\
		"syscall"
	if kexec -l "$KERNEL_IMAGE" &>> /dev/null; then
		kexec -u
		fail "Kexec loaded unsigned image - unloading"
	else
		v_out "Correctly prevented kexec of an unsigned image"
	fi
}

sign_image () {
	v_out "Signing kernel image with provided key..."
	evmctl ima_sign -f "$KERNEL_IMAGE" -k "$IMA_KEY"
}

check_signed_KEXEC_FILE_LOAD () {
	v_out "Testing loading a signed kernel image using KEXEC_FILE_LOAD"\
		"syscall"
	if ! kexec -s -l "$KERNEL_IMAGE" &>> /dev/null; then
		fail "kexec rejected a signed image - possibly due to PECOFF"\
			"signature"
	else
		v_out "kexec correctly loaded signed image...unloading"
	fi

	kexec -s -u
}

check_signed_KEXEC_LOAD () {
	v_out "Testing loading a signed kernel image \
	(without file descriptor) using KEXEC_LOAD syscall"

	if kexec -l "$KERNEL_IMAGE" &>> /dev/null; then
		kexec -u
		fail "Signed image was allowed to load without file descriptor"\
		"for appraisal. Unloading."
	fi

	v_out "Correctly prevented loading"
}

cleanup () {
v_out "Cleaning up..."
if [ -n "$TEMP_LOCATION" ]; then
	rm "$TEMP_LOCATION"
fi
}


EVMTEST_require_root
echo "[*] Starting test: $TEST"
parse_args "$@"
get_image
write_hash
load_policy
check_unsigned_KEXEC_FILE_LOAD
check_unsigned_KEXEC_LOAD
sign_image
check_signed_KEXEC_FILE_LOAD
check_signed_KEXEC_LOAD
cleanup
passed
