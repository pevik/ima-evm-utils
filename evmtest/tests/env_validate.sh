#!/bin/bash
# This test serves to validate a kernel build for running with EVMTEST

TEST="env_validate"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh
VERBOSE=0
CONFIG_FILE=""

usage () {
	echo ""
	echo "env_validate [-c <config>]|-r] [-vh]"
	echo ""
	echo "	This test validates that a kernel is properly configured, "
	echo "	based on either the provided config file or the builtin"
	echo "	kernel image config file of the running system"
	echo ""
	echo "	-c	Kernel config file"
	echo "	-r	Will attempt to pull running config"
	echo "	-v	Verbose testing"
	echo "	-h	Displays this help message"
	echo ""
}

parse_args () {
	TEMP=$(getopt -o 'hc:rv' -n 'env_validate' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
		-h) usage; exit 0 ;;
		-c) CONFIG="$2"; shift 2;;
		-r) RUNNING=1; shift;;
		-v) VERBOSE=1; shift;;
		--) shift; break;;
		*) echo "[*] Unrecognized option $1"; exit 1 ;;
		esac
	done

	# One must be defined
	if [ -z "$CONFIG" ] && [ -z "$RUNNING" ]; then
		usage
		exit 1
	# But not both
	elif [ -n  "$CONFIG" ] && [ -n "$RUNNING" ]; then
		usage
		exit 1
	fi
}

# Validate that a variable has been set to a value
validate () {
	search="$1=$2"
	for line in "${lines[@]}"
	do
	:
		if test "${line}" == "${search}"; then
			return
		fi
	done
	INVALID_DEFINITION+=( "$search" )
}

# Validate that a variable is defined
validate_defined () {
	search="$1"
	for line in "${lines[@]}"
	do
	:
		if test "${line#*$search}" != "$line"; then
			if test "${line#*"#"}" == "$line"; then
				return
			fi
		fi
	done
	NOT_DEFINED+=( "$1" )
}

# Attempt to find the config on /proc. If not on proc, try extracting from
# the image, and then the configs.ko module using extract-ikconfig.
locate_config () {
	if [ -n "$RUNNING" ]; then
		CONFIG_FILE=$(mktemp)
		if ! gunzip -c /proc/config.gz &>> "$CONFIG_FILE";  then
			# Clear errors
			rm "$CONFIG_FILE"

			v_out "$WARN_PROC"

			build=$(uname -r)
			scripts=/lib/modules/"$build"/build/scripts
			extract="$scripts"/extract-ikconfig
			image=/boot/vmlinuz-"$build"
			mod=/lib/modules/"$build"/kernel/kernel/configs.ko

			if ! "$extract" "$image" &>> "$CONFIG_FILE"; then
				rm "$CONFIG_FILE"
				v_out "$WARN_IMAGE"

				if ! "$extract" "$mod" &>> "$CONFIG_FILE"; then
					fail "$NO_CONF"
				fi
			fi
		fi
		v_out "Extracted config to $CONFIG_FILE"
	fi

	if [ -n "$CONFIG" ]; then
		CONFIG_FILE="$CONFIG"
	fi

	if [ ! -f "$CONFIG_FILE" ]; then
		fail "Could not find config file"
	fi
}

check_config () {
	v_out "Parsing .config file..."

	IFS=$'\n' read -d '' -r -a lines < "$CONFIG_FILE"

	v_out "Validating keyring configuration..."
	# Keyring configuration
	validate "CONFIG_SYSTEM_EXTRA_CERTIFICATE" "y"
	validate_defined "CONFIG_SYSTEM_EXTRA_CERTIFICATE_SIZE"
	validate "CONFIG_SYSTEM_TRUSTED_KEYRING" "y"
	validate_defined "CONFIG_SYSTEM_TRUSTED_KEYS"

	v_out "Validating integrity configuration..."
	# Integrity configuration
	validate "CONFIG_INTEGRITY" "y"
	validate "CONFIG_INTEGRITY_SIGNATURE" "y"
	validate "CONFIG_INTEGRITY_ASYMMETRIC_KEYS" "y"
	validate "CONFIG_INTEGRITY_TRUSTED_KEYRING" "y"
	validate "CONFIG_INTEGRITY_AUDIT" "y"

	v_out "Validating IMA configuration..."
	# IMA configuration
	validate "CONFIG_IMA" "y"
	validate "CONFIG_IMA_MEASURE_PCR_IDX" "10"
	validate "CONFIG_IMA_LSM_RULES" "y"
	validate "CONFIG_IMA_SIG_TEMPLATE" "y"
	validate_defined "CONFIG_IMA_DEFAULT_TEMPLATE"
	validate_defined "CONFIG_IMA_DEFAULT_HASH_SHA256"
	validate_defined "CONFIG_IMA_DEFAULT_HASH"
	validate "CONFIG_IMA_WRITE_POLICY" "y"
	validate "CONFIG_IMA_READ_POLICY" "y"
	validate "CONFIG_IMA_APPRAISE" "y"
	validate "CONFIG_IMA_TRUSTED_KEYRING" "y"
	validate "CONFIG_IMA_LOAD_X509" "y"
	validate_defined "CONFIG_IMA_X509_PATH"
	v_out "Validating module signing configuration..."
	# Module signing configuration
	validate_defined "CONFIG_MODULE_SIG_KEY"
	validate "CONFIG_MODULE_SIG" "y"

	if [ ${#INVALID_DEFINITION[@]} != 0 ]; then
		v_out "The following Kconfig variables are incorrectly defined:"
		for var in "${INVALID_DEFINITION[@]}"; do
			v_out "$var"
		done
	fi

	if [ ${#NOT_DEFINED[@]} != 0 ]; then
		v_out "The following Kconfig variables need to be defined:"
		for var in "${NOT_DEFINED[@]}"; do
			v_out "$var"
		done

	fi

	[ "${#NOT_DEFINED[@]}" -eq 0 ] && [ "${#INVALID_DEFINITION[@]}" -eq 0 ]
	code=$?

	if [ -n "$RUNNING" ]; then
		rm "$CONFIG_FILE"
	fi

	if [ "$code" != 0 ]; then
		fail
	fi
}

WARN_PROC="Configuration not on /proc, will attempt to extract from image"
WARN_IMAGE="Unable to extract from image, will attempt to extract from module"
NO_CONF="Unable to extract from module. Extracting kernel configuration
	requires CONFIG_IKCONFIG to be enabled. Support for reading from /proc
	is enabled with CONFIG_IKCONFIG_PROC"
INVALID_DEFINITION=()
NOT_DEFINED=()

echo "[*] Starting test: $TEST"
parse_args "$@"
locate_config
check_config
passed
