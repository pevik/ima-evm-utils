#!/bin/bash

TEST="r_env_validate"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source $ROOT/files/common.sh
VM_VALIDATE=0
VERBOSE=0
CONFIG_FILE=""
# This test serves to validate a kernel build for running with EVMTEST
# optional argument for validating compatibility with a VM

usage () {
	echo ""
	echo "env_validate [-c <config>]|-r] [-vh]"
	echo ""
	echo "	This test will validate that a kernel build is compatible with"
	echo "	evmtest, and is configured correctly. It can be pointed toward"
	echo "	a build directory where a .config file is provided, or it can"
	echo "	attempt to pull the config out of a running kernel."
	echo ""
	echo "	-c,--config	Kernel config file"
	echo "	-r,--running	Will attempt to pull running config"
	echo "	-V,--vm		Will validate that build is vm compatible"
	echo "	-v,--verbose	Verbose testing [Do not use in test harness]"
	echo "	-h,--help	Displays this help message"
	echo ""

}

TEMP=`getopt -o 'hc:rVv' -l 'help,config:,running,vm,verbose' -n\
		 'env_validate' -- "$@"`
eval set -- "$TEMP"

while true ; do
	case "$1" in
	-h|--help) usage; exit 0 ;;
	-c|--config) CONFIG=$2; shift 2;;
	-r|--running) RUNNING=1; shift;;
	-V|--vm) VM_VALIDATE=1; shift;;
	-v|--verbose)	VERBOSE=1; shift;;
	--) shift; break;;
	*) echo "[*] Unrecognized option $1"; exit 1 ;;
	esac
done

# One must be defined
if [[ -z $CONFIG && -z $RUNNING ]]; then
	usage
	exit 1
# But not both
elif [[ ! -z $CONFIG && ! -z $RUNNING ]]; then
	usage
	exit 1
fi

INVALID_DEFINITION=() # Variables that aren't assigned correctly
NOT_DEFINED=() # Variables that need to be defined

function validate {
	# Test that a variable is defined, and that it has a certain
	# value

	eval value='$'$1
	if [[ -z "$value" ]]; then
		NOT_DEFINED+=( "$1" )
	elif [[ "$value" != "$2" ]]; then
		INVALID_DEFINITION+=( "$1" )
	fi
}

function validate_defined {
	# Test that a variable is defined - don't care specifically what that
	# value is

	eval value='$'$1
	if [[ -z $value ]]; then
		NOT_DEFINED+=( "$1" )
	fi
}

begin

# If we want to pull the running config
if [[ ! -z $RUNNING ]]; then
	EVMTEST_require_root
	# If we are pulling the running config - root will be required
	v_out "Trying to find running kernel configuration..."
	CONFIG_FILE=`mktemp`
	if [[ -f /proc/config.gz ]]; then
		v_out "Located kernel config in /proc/config.gz"
		gunzip -c /proc/config.gz > $CONFIG_FILE
		v_out "Placed config in $CONFIG_FILE"
	else
		v_out "Trying to load configs module to expose config"
		if [[ -e "/lib/modules/`uname -r`/kernel/kernel/configs.ko" ]];
		then
			modprobe configs &>> /dev/null

			gunzip -c /proc/config.gz > $CONFIG_FILE
		else

			v_out "Could not load configs - kernel may not have"
			v_out "compiled with ability to get config. Rebuild"
			v_out "with CONFIG_IKCONFIG enabled."
			v_out "modprobe loaded configs - reattempting read"
		fi
	fi
fi

if [[ ! -z $CONFIG ]]; then
	CONFIG_FILE=$CONFIG
fi

if [[ ! -f $CONFIG_FILE ]]; then
	fail "Could not find config file"
fi

v_out "Parsing .config file..."
# Not safe to source .config file - this is a safer way of reading in variables
IFS=$'\n'
for line in $(grep -v -E "#" $CONFIG_FILE); do
	declare $line
done


# Set all desired values below here
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

if [[ $VM_VALIDATE == 1 ]]; then
	v_out "Validating VM configuration"

	validate "CONFIG_BLK_MQ_VIRTIO" "y"
	validate "CONFIG_MEMORY_BALLOON" "y"
	validate "CONFIG_VIRTIO_BLK" "y"
	validate "CONFIG_SCSI_VIRTIO" "y"
	validate "CONFIG_HW_RANDOM_VIRTIO" "y"
	validate "CONFIG_VIRTIO" "y"
	validate "CONFIG_VIRTIO_MENU" "y"
	validate "CONFIG_VIRTIO_PCI" "y"
	validate "CONFIG_VIRTIO_PCI_LEGACY" "y"
	validate "CONFIG_VIRTIO_BALLOON" "y"
fi

if [ ${#INVALID_DEFINITION[@]} != 0 ]; then
	v_out "The following configuration variables have the wrong value"
	for var in "${INVALID_DEFINITION[@]}"; do
		eval value='$'$var
		v_out "$var ($value)"
	done
fi

if [ ${#NOT_DEFINED[@]} != 0 ]; then
	v_out "The following configuration variables need to be defined"
	for var in "${NOT_DEFINED[@]}"; do
		v_out $var
	done

fi

[[ "${#NOT_DEFINED[@]}" -eq 0 ]] && [[ "${#INVALID_DEFINITION[@]}" -eq 0 ]]
code=$?

if [[ ! -z $RUNNING ]]; then
	rm $CONFIG_FILE
fi

if [[ $code == 0 ]]; then
	passed
else
	fail
fi
