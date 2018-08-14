#!/bin/bash

# This is the EVMTest common.sh file
# This is sourced at the top of a test file to provide common variables,
# paths, and functions.

function EVMTEST_forbid_root {
	if [[ $UID == 0 ]]; then
		echo "[!] This test should not be run as root"
		exit 1
	fi
}

function EVMTEST_require_root {
	if [[ $UID != 0 ]]; then
		echo "[!] This test must be run as root"
		exit 1
	fi
}

# verbose_output function - will only echo output if verbose is true
# otherwise, output is muted
function v_out {
	[ "$VERBOSE" != "0" ] && { echo "[*] $@" ; return ; }
}

# Function to fail a test
function fail {
	if [[ $VERBOSE != 0 ]]; then
		if [[ ! -z "$@" ]]; then
			echo "[!] $@"
		fi
	fi
	echo "[*] TEST: FAILED"
	exit 1
}

function begin {
	echo "[*] Starting test: $TEST"
}

function passed {
	echo "[*] TEST: PASSED"
	exit 0
}
# Everything exported should be prefixed with EVMTEST_
EVMTEST_SECFS_EXISTS=`findmnt securityfs`
EVMTEST_SECFS=`findmnt -f -n securityfs -o TARGET`
EVMTEST_BOOT_OPTS=`cat /proc/cmdline`
