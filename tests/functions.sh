#!/bin/bash
#
# ima-evm-utils tests bash functions
#
# Copyright (C) 2019 Vitaly Chikunov <vt@altlinux.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# tests accounting
declare -i testspass=0 testsfail=0 testsskip=0

# exit codes (compatible with automake)
declare -r OK=0
declare -r FAIL=1
declare -r HARDFAIL=99 # hard failure no matter testing mode
declare -r SKIP=77     # skip test

# you can set env VERBOSE=1 to see more output from evmctl
V=vvvv
V=${V:0:$VERBOSE}
V=${V:+-$V}

# require particular executables to be present
_require() {
  ret=
  for i; do
    if ! type $i; then
      echo "$i is required for test"
      ret=1
    fi
  done
  [ $ret ] && exit $HARDFAIL
}

# only allow color output on tty
if tty -s; then
     RED=$'\e[1;31m'
   GREEN=$'\e[1;32m'
  YELLOW=$'\e[1;33m'
    BLUE=$'\e[1;34m'
    CYAN=$'\e[1;36m'
    NORM=$'\e[m'
fi

# Define FAILEARLY to exit testing on the first error.
exit_early() {
  if [ $FAILEARLY ]; then
    exit $1
  fi
}

# Test mode determined by TNEG variable:
#   undefined: to positive testing
#   defined: negative testing
TNEG=
TMODE=+

# Eval positive test and account its result
pos() {
  TNEG= TMODE=+
  [ "$VERBOSE" ] && echo "Start positive test $*"
  eval "$@"
  E=$?
  [ "$VERBOSE" ] && echo "Stop ($E) positive test $*"
  case $E in
    0)  testspass+=1 ;;
    77) testsskip+=1 ;;
    99) testsfail+=1; exit_early 1 ;;
    *)  testsfail+=1; exit_early 2 ;;
  esac
}

# Eval negative test and accoutn its result
neg() {
  TNEG=1 TMODE=-
  [ "$VERBOSE" ] && echo "Start negative test $*"
  eval "$@"
  E=$?
  [ "$VERBOSE" ] && echo "Stop ($E) negative test $*"
  case $E in
    0)  testsfail+=1; exit_early 3 ;;
    77) testsskip+=1 ;;
    99) testsfail+=1; exit_early 4 ;;
    *)  testspass+=1 ;;
  esac
  TNEG= # Restore default
}

# return true if current test is positive
_is_positive_test() {
  [ -z "$TNEG" ]
}

# return true if current test is negative
_is_negative_test() {
  [ "$TNEG" ]
}

# Color following text to red if it's real error
red_if_pos() {
  _is_positive_test && echo $@ $RED
}

norm_if_pos() {
  _is_positive_test && echo $@ $NORM
}

DEL=
FOR=
# _evmctl_run should be run as `_evmctl_run ... || return'
_evmctl_run() {
  local cmd=$1 out=$1-$$.out
  # Additional parameters:
  # FOR: append to text as 'for $FOR'
  # DEL: additional files to rm if test failed

  set -- evmctl $V ${ENGINE:+--engine $ENGINE} "$@"
  echo $YELLOW$TMODE $*$NORM
  eval "$@" >$out 2>&1
  ret=$?

  if [ $ret -ge 126 -a $ret -lt 255 ]; then
    echo $RED
    echo "evmctl $cmd failed hard with ($ret) ${FOR:+for $FOR}"
    sed 's/^/  /' $out
    echo $NORM
    rm $out $DEL
    FOR= DEL=
    return $SKIP
  elif [ $ret -gt 0 ]; then
    red_if_pos
    echo "evmctl $cmd failed" ${TNEG:+properly} "with ($ret) ${FOR:+for $FOR}"
    sed 's/^/  /' $out
    norm_if_pos
    rm $out $DEL
    FOR= DEL=
    return $FAIL
  elif _is_negative_test; then
    echo $RED
    echo "evmctl $cmd wrongly succeeded ${FOR:+for $FOR}"
    sed 's/^/  /' $out
    echo $NORM
  else
    [ "$VERBOSE" ] && sed 's/^/  /' $out
  fi
  rm $out
  FOR= DEL=
  return $OK
}

_extract_ima_xattr() {
  local file=$1 out=$2 pref=$3

  getfattr -n user.ima -e hex $file \
    | grep ^user.ima= \
    | sed s/^user.ima=$pref// \
    | xxd -r -p > $out
}

_test_ima_xattr() {
  local file=$1 pref=$2

  if ! getfattr -n user.ima -e hex $file | egrep -qx "user.ima=$pref"; then
    red_if_pos
    echo "Did not find expected hash${FOR:+ for $FOR}:"
    echo "    user.ima=$pref"
    echo ""
    echo "Actual output below:"
    getfattr -n user.ima -e hex $file | sed 's/^/    /'
    norm_if_pos
    rm $file
    FOR=
    return $FAIL
  fi
  FOR=
}

_enable_gost_engine() {
  # Do not enable if it's already working (enabled by user)
  if ! openssl md_gost12_256 /dev/null >/dev/null 2>&1 \
    && openssl engine gost >/dev/null 2>&1; then
    ENGINE=gost
  fi
}

# Show test stats and exit into automake test system
# with proper exit code (same as ours).
_report_exit() {
  if [ $testsfail -gt 0 ]; then
    echo "=============================="
    echo "Run with FAILEARLY=1 $0 $@"
    echo "To stop after first failure"
    echo "=============================="
  fi
  [ $testspass -gt 0 ] && echo -n $GREEN || echo -n $NORM
  echo -n "PASS: $testspass"
  [ $testsskip -gt 0 ] && echo -n $YELLOW || echo -n $NORM
  echo -n " SKIP: $testsskip"
  [ $testsfail -gt 0 ] && echo -n $RED || echo -n $NORM
  echo " FAIL: $testsfail"
  echo $NORM
  if [ $testsfail -gt 0 ]; then
    exit $FAIL
  elif [ $testspass -gt 0 ]; then
    exit $OK
  else
    exit $SKIP
  fi
}
