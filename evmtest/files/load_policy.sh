#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )/.."
source $ROOT/files/common.sh
EVMTEST_require_root

#This script loads the IMA policy either by replacing the builtin
#policies specified on the boot command line or by appending the policy
#rules to the existing custom policy.

# This program assumes that the running kernel has been compiled with
# CONFIG_IMA_WRITE_POLICY=y
# To validate this, run env_validate <path_to_kernel_build>
# Otherwise, this will fail

if [[ "$#" !=  1 || "$1" == "-h" ]]; then
	echo "load_policy - load an IMA policy."
	echo "Usage: load_pol <policy pathname>"
	exit
fi

IMA_POLICY_LOCATION=$EVMTEST_SECFS/ima/policy
EVMTEST_POLICY_LOCATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" \
	>/dev/null && pwd )/policies"
if [[ ! -e $EVMTEST_POLICY_LOCATION/$1 ]]; then
	echo "[!] Policy: $1 not found, ensure it is in files/policies"
	exit 1
fi
TO_LOAD=$EVMTEST_POLICY_LOCATION/$1
echo $TO_LOAD > $IMA_POLICY_LOCATION
if [[ $? != 0 ]]; then
	echo "[!] Load failed - see dmesg"
	exit 1
else
	echo "[*] Policy update completed"
fi

exit 0
