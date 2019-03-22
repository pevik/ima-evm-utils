#!/bin/bash

# This is the EVMTest common.sh file
# This is sourced at the top of a test file to provide common variables,
# paths, and functions.

EVMTEST_forbid_root () {
	if [ "$UID" == 0 ]; then
		echo "[!] This test should not be run as root"
		exit 1
	fi
}

EVMTEST_require_root () {
	if [ "$UID" != 0 ]; then
		echo "[!] This test must be run as root"
		exit 1
	fi
}

# verbose_output function - will only echo output if verbose is true
# otherwise, output is muted
v_out () {
	[ "$VERBOSE" != "0" ] && { echo "[*]" "$@" ; return ; }
}

# Function to fail a test
fail () {
	if [ "$VERBOSE" != 0 ]; then
		if [ -n "$*" ]; then
			echo "[!]" "$@"
		fi
	fi
	echo "[*] TEST: FAILED"
	exit 1
}

passed () {
	echo "[*] TEST: PASSED"
	exit 0
}

EVMTEST_check_policy_readable () {
	v_out "Attempting to read current policy..."
	if ! cat "$EVMTEST_SECFS"/ima/policy &>> /dev/null; then
		fail "Could not read running policy. Kernel must be"\
		"configured with Kconfig option CONFIG_IMA_READ_POLICY=y"
	fi
	v_out "Policy is readable"
}

# Everything exported should be prefixed with EVMTEST_
EVMTEST_SECFS_EXISTS=$(findmnt securityfs)
EVMTEST_SECFS=$(findmnt -f -n securityfs -o TARGET)
EVMTEST_BOOT_OPTS=$(cat /proc/cmdline)

export EVMTEST_SECFS_EXISTS
export EVMTEST_SECFS
export EVMTEST_BOOT_OPTS
