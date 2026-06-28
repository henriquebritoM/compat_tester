#!/bin/sh
#
#	compile and run LTP syscall testes on NetBSD, using Compat Linux
#
#	Usage: 
# 	todo
#
# 	Requirements:
# 	- gmake
# 	- pkgconf
# 	- suse_gcc12-15.5
# 	- curl
# 	- e2fsprogs (for ext* testing)
# 	- module compat_linux enabled

set -e

# Directory where this script is located. Used as root for other paths.
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Directory where the LTP tests will be cloned
LTP_DIR="${BASE_DIR}/ltp"

# Base directory for the syscalls subdirectory inside ltp
SYSCALL_DIR="${LTP_DIR}/testcases/kernel/syscalls"

# Optional: Used to specify one syscalls subdirectory inside SYSCALL_DIR
SYSCALL_COMPLEMENT=""

# Directory where compiled tests will be placed
BINARIES_DIR="${BASE_DIR}/bin"
export LTPROOT="${BINARIES_DIR}"
export PATH="${PATH}:${BINARIES_DIR}/testcases/bin"

# Directory where logs from tested syscalls are stored
LOGS_DIR="${BASE_DIR}/syscall_logs"

# Controls the level of verbosity:
# -1 = Silent. Only logs
# 0  = Standard. Only displays only stderr and logs
# 1  = Verbose.  Display stdin, stdout and logs 
VERBOSITY=0

# What compiler to use. Default searches for suse_gcc12-15.5
CC="/emul/linux/usr/bin/gcc-12"

# Some tests require a block device to be present.
# The way LTP tries to get it does not work on NetBSD, so it is necessary 
# to pass through a enviroment variable
BLK_FILE="${BASE_DIR}/test.img"
BLK_VND="vnd0"
BLK_DEV="/dev/${BLK_VND}a"
IS_BLK_MOUNTED=0
export LTP_DEV="${BLK_DEV}"

# Release version of the tests
LTP_URL=$(curl -s https://api.github.com/repos/linux-test-project/ltp/releases/latest | \
	grep "browser_download_url.*ltp-full-.*\.tar\.xz\"" | \
	cut -d'"' -f4)

# Latest release available for LTP
LTP_RELEASE=$(echo "${LTP_URL}" | sed 's/https:.*\///; s/.tar.xz//')

LTP_VERSION_FILE="${BASE_DIR}/ltp_version"

if ! [ -e "${LTP_VERSION_FILE}" ]; then
	echo 0 > "${LTP_VERSION_FILE}"
fi

# Currently installed LTP version
LTP_CURRENT_VERSION="$(cat ltp_version)"

if ! [ -e "${LTP_DIR}" ]; then
	mkdir "${LTP_DIR}"
fi

if ! [ -e "${BINARIES_DIR}" ]; then
	mkdir "${BINARIES_DIR}"
fi

if ! [ -e "${LOGS_DIR}" ]; then
	mkdir "${LOGS_DIR}"
fi

if ! [ -e "${BLK_FILE}" ]; then
	dd if=/dev/zero of=test.img bs=1m count=512
fi

mount_ltp_dev() {

	if ! [ "$(vnconfig -l ${BLK_DEV})" != "${BLK_DEV}: not in use" ]; then
		# Stop early if the vnd target is already in use
		echo "${BLK_DEV} is already in use. Cannot continue"
		return
	else
		# Mount the vnd if the target is free
		vnconfig "${BLK_VND}" "${BLK_FILE}"
		IS_BLK_MOUNTED=1 # Mark that we mounted
	fi
}

unmount_ltp_dev() {
	# checks if the vnd was mounted by the script
	if [ "${IS_BLK_MOUNTED}" -eq 1 ]; then
		vnconfig -u "${BLK_VND}"
		IS_BLK_MOUNTED=0
	fi
}

is_empty_dir() {
	[ -z "$(ls -A "$1")" ]
}

clean_logs() {
	rm -rf "${LOGS_DIR:?}"/*
}

clean_binaries() {
	rm -rf "${BINARIES_DIR:?}"/*
}

# Clear previous LTP installation
clean_ltp_source() {
	rm -rf "${LTP_DIR:?}/*"

	# Reset some related vars
	echo 0 > "${LTP_VERSION_FILE}"
	LTP_CURRENT_VERSION=0
}

# clear binaries and logs
clean() {
	clean_binaries 
	clean_logs 
}

is_ltp_latest() {
	echo "=> checking if the latest version of LTP is being used"

	# Not in the latest release
	if [ "${LTP_CURRENT_VERSION}" != "${LTP_RELEASE}" ]; then
		echo "- Not in the latest version"
		return 1
	fi

	echo "- Already up to date"
	return 0
}

# Installs LTP tests.
install_ltp() {

	echo "=> Downloading the latest LTP release"

	echo "${LTP_RELEASE}" > "ltp_version"
	curl -OLs "${LTP_URL}"
	tar -xf "${LTP_RELEASE}.tar.xz" -C "${LTP_DIR}" --strip-components=1
	rm "${LTP_RELEASE}.tar.xz" # no reason to keep the tar
}

are_tests_compiled() {
	
	test_location="${BINARIES_DIR}/testcases/bin/${SYSCALL_COMPLEMENT}"

	# We only need to find one test, as they are compiled all together
	for t in "${test_location}"[0-9]*; do
    	if [ -e "${t}" ]; then
			return 0
		fi
	done

	return 1
}

compile_setup() {
	cd "${LTP_DIR}"

	case "${VERBOSITY}" in 
		-1)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}" \
				>/dev/null 2>&1
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)" \
				>/dev/null 2>&1
			;;
		0)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}" \
				1>/dev/null
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)" \
				1>/dev/null
			;;
		1)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}"
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)"
			;;
	esac
}
 
compile_tests() {
	cd "${LTP_DIR}"
	runtest_file="${BINARIES_DIR}/runtest/syscalls"
	
	if ! [ -e "${runtest_file}" ]; then
		compile_setup
	fi

	case "${VERBOSITY}" in 
		-1)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" >/dev/null 2>&1
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" >/dev/null 2>&1
			;;
		0)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" 1>/dev/null
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" 1>/dev/null
			;;
		1)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}"
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_COMPLEMENT}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}"
			;;
	esac
	
	cd "${BASE_DIR}"
	return
}

# Some tests requeire args to be passed in the cli
# this funcion takes the name of the test and returns
# its args
get_test_args() {
		
	runtest_file="${BINARIES_DIR}/runtest/syscalls"

	args="$(grep -E "^${1} " "${runtest_file}" |
			sed "s/$1 *//g")"

	echo "${args}"
}

run_test_for_one_syscall() {
	syscall="$1"

	basename="$(basename "${syscall}")"
	
	bin_dir="${BINARIES_DIR}/testcases/bin"
	output_file="${LOGS_DIR}/${basename}"

	# Cleans output_file
	echo "" > "${output_file}"

	# Globs only the tests that have the syscall_name + number
	# to avoid matching syscalls with similar name (like open & openat)
	for syscall_test in "${bin_dir}/${basename}"[0-9]*; do
		
		test_name="$(basename "${syscall_test}")"
		args="$(get_test_args "${test_name}")"
		set -- $args # word splitting is desired

		{
			echo "==================================================",
			echo "   TEST: ${test_name}",
			echo "==================================================",
			echo "",
		} >> "${output_file}"

		echo "syscall_test: ${syscall_test}"

		"${syscall_test}" "$@" 2>&1 | tee -a "${output_file}" || true

	done
}

# 
run_tests() {

	mount_ltp_dev 
	
	if ! [ -z "${SYSCALL_COMPLEMENT}" ]; then
		run_test_for_one_syscall "${SYSCALL_COMPLEMENT}"
	else
		for syscall in "${SYSCALL_DIR}"/*/; do
			run_test_for_one_syscall "${syscall}"
		done
	fi

	unmount_ltp_dev 
}

main() {

	should_clear_all=1
	should_clear_bin=1
	should_clear_ltp=1
	should_compile=1
	should_install=1
	should_exit=1
	
	while [ "$#" -gt 0 ]; do
		arg="$1"
	
		if [ "${arg}" = "--clean" ]; then
			should_clear_all=0
			should_exit=0
		elif [ "${arg}" = "--update" ]; then
			if ! is_ltp_latest; then
				should_clear_bin=0
				should_clear_ltp=0
				should_install=0
			fi
			should_exit=0
		elif [ "${arg}" = "--reinstall" ]; then
			should_clear_ltp=0
			should_clear_bin=0
			should_install=0
			should_exit=0
		elif [ "${arg}" = "--compile" ]; then
			should_clear_bin=0
			should_compile=0
			should_exit=0
		elif [ "${arg}" = "--syscall" ]; then
			shift #consumes the arg
			SYSCALL_COMPLEMENT="$1" # uses the next
		elif [ "${arg}" = "--verbose" ]; then
			VERBOSITY=1
		elif [ "${arg}" = "--silent" ]; then
			VERBOSITY=-1
		else 
			echo "Invalid Option: '${arg}'"
			return 
		fi
	
		shift
	done

	if [ "${should_clear_all}" -eq 0 ]; then
		clean
		return
	fi
	
	if [ "${should_clear_bin}" -eq 0 ]; then
		clean_binaries
	fi

	if [ "${should_clear_ltp}" -eq 0 ]; then
		clean_ltp_source
	fi

	if [ "${should_install}" -eq 0 ]; then
		install_ltp
	fi

	if [ "${should_compile}" -eq 0 ]; then
		compile_tests
	fi 

	# Some options should not automatically run the tests
	if [ "${should_exit}" -eq 0 ]; then
		return
	fi

	if is_empty_dir "${LTP_DIR}"; then 
		install_ltp
	fi

	if ! are_tests_compiled; then 
		compile_tests
	fi

	run_tests 
}

main "$@"
