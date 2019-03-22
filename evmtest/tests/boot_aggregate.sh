#!/bin/bash
# Author: David Jacobson <davidj@linux.ibm.com>
TEST="boot_aggregate"

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source "$ROOT"/files/common.sh

VERBOSE=0
TPM_VERSION="2.0"
# This test validates the eventlog against the hardware PCRs in the TPM, and
# the boot aggregate against IMA.

usage (){
	echo "boot_aggregate [-hv]"
	echo ""
	echo "	This test must be run as root"
	echo ""
	echo "	This test validates PCRs 0-7 in the TPM"
	echo "	It also validates the boot_aggregate based those PCRs"
	echo "	against what IMA has recorded"
	echo ""
	echo "	-h	Display this help message"
	echo "	-v	Verbose logging"
}

parse_args () {
	TEMP=$(getopt -o 'hv'  -n 'boot_aggregate' -- "$@")
	eval set -- "$TEMP"

	while true ; do
		case "$1" in
			-h) usage; exit; shift;;
			-v) VERBOSE=1; shift;;
			--) shift; break;;
			*) echo "[*] Unrecognized option $1"; exit 1 ;;
		esac
	done
}

check_requirements () {
	v_out "Checking if securityfs is mounted..."
	if [ -z "$EVMTEST_SECFS_EXISTS" ]; then
		fail "securityfs not found..."
	fi

	v_out "Verifying TPM is present..."
	if [ ! -d "$EVMTEST_SECFS/tpm0" ]; then
		fail "Could not locate TPM in $EVMTEST_SECFS"
	fi

	v_out "TPM found..."

	v_out "Checking if system supports reading event log..."

	if [ ! -f "$EVMTEST_SECFS"/tpm0/binary_bios_measurements ]; then
			fail "Kernel does not support reading BIOS measurements,
			please update to at least 4.16.0"
	fi

	v_out "Verifying TPM Version"
	if [ -e /sys/class/tpm/tpm0/device/caps ]; then
		TPM_VERSION="1.2"
	fi
}

check_pcrs () {
	v_out "Grabbing PCR values..."
	local pcrs=() # array to store the Hardware PCR values
	local sim_pcrs=() # What PCRs should be according to the event log
	local eventextend=tsseventextend
	local pcrread="tsspcrread -halg sha1"
	local eventlog=/sys/kernel/security/tpm0/binary_bios_measurements

	if [ "$TPM_VERSION" == "1.2" ]; then
		eventextend=tss1eventextend
		pcrread=tss1pcrread
	fi

	for ((i=0; i<=7; i++)); do
		pcrs[i]=$(TPM_INTERFACE_TYPE=dev $pcrread -ha "$i" -ns)
	done

	local output=$(mktemp -u)
	"$eventextend" -if "$eventlog" -sim -ns > "$output"

	# Some PTT's are using TPM 1.2 event log format.  Retry on failure.
	if [ $? -ne 0 ]; then
		eventextend=tss1eventextend
		"$eventextend" -if "$eventlog" -sim -ns > "$output"
	fi

	IFS=$'\n' read -d '' -r -a lines < "$output"
	rm "$output"

	for line in "${lines[@]}"
		do
		:
		sim_pcrs+=( "$(echo "$line" | cut -d ':' -f2 | \
				tr -d '[:space:]')" )
		if printf '%s' "$line" | grep -E -q "boot aggregate"; then
			tss_agg=$(echo "$line" | cut -d ':' -f2 | \
				tr -d '[:space:]')
		fi
	done

	v_out "Validating PCRs.."
	for ((i=0; i<=7; i++)); do
		v_out "SIM PCR [$i]: ${sim_pcrs[$i]}"
		v_out "TPM PCR [$i]: ${pcrs[$i]}"
		if [  "${pcrs[$i]}" != "${sim_pcrs[$i]}" ]; then
			v_out "PCRs are incorrect..."
			fail "Mismatch at PCR $i "
		else
			v_out "PCR $i validated..."
		fi
	done
}

check_boot_aggregate () {
	v_out "Validating Boot Aggregate..."
	ima_agg=$(grep boot_aggregate \
	"$EVMTEST_SECFS"/ima/ascii_runtime_measurements| head -1 | cut \
		-d ":" -f2|cut -d " " -f1)
	v_out "TSS BOOT AGG: $tss_agg"
	v_out "IMA BOOT AGG: $ima_agg"

	if [ "$tss_agg" != "$ima_agg" ]; then
		fail "Boot Aggregate is inconsistent"
	else
		v_out "Boot Aggregate validated"
	fi
}

EVMTEST_require_root
echo "[*] Starting test: $TEST"
parse_args "$@"
check_requirements
check_pcrs
check_boot_aggregate
passed
