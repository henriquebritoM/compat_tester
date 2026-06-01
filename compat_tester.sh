#!/bin/sh
#
#	compile and run LTP syscall testes on NetBSD, using Compat Linux
#
#	Usage: 
# 	todo
#
# 	Requirements:
# 	- autoconf
# 	- automake
# 	- gmake
# 	- m4
# 	- pkgconf
# 	- suse_gcc12-15.5
# 	- curl
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

# Directory where logs from tested syscalls are stored
LOGS_DIR="${BASE_DIR}/syscall_logs"

# What compiler to use. Default searches for suse_gcc12-15.5
CC="/emul/linux/usr/bin/gcc-12"

# If the script should recompile the tests
FORCE_COMPILE=0

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

is_empty_dir() {
	[ -z "$(ls -A "$1")" ]
}

# clear only the binaries
clean() {
	rm -rf "${BINARIES_DIR:?}"/*
}

clean_logs() {
	rm -rf "${LOGS_DIR:?}"/*
}

# Clear previous LTP installation
clear_ltp() {
	echo "Clearing local LTP files"

	# clears some related vars
	echo 0 > "${LTP_VERSION_FILE}"
	LTP_CURRENT_VERSION=0

	# clears the source code
	rm -rf "${LTP_DIR:?}" 

	# clears the binaries
	clean
}

is_ltp_latest() {
	echo "checking if the latest version of LTP is being used"

	# Not in the latest release
	if [ "${LTP_CURRENT_VERSION}" != "${LTP_RELEASE}" ]; then
		echo "Not in the latest version"
		return 1
	fi

	echo "Already up to date"
	return 0
}

# Installs LTP tests. Clears previous installation, if present
install_ltp() {

	# No point in installing without clearing residues
	clear_ltp

	echo "Downloading the latest LTP release"

	mkdir "${LTP_DIR}"
	echo "${LTP_RELEASE}" > "ltp_version"
	curl -OLs "${LTP_URL}"
	tar -xf "${LTP_RELEASE}.tar.xz" -C "${LTP_DIR}" --strip-components=1
	rm "${LTP_RELEASE}.tar.xz" # no reason to keep the tar
}

# updates LTP to the latest release
update_ltp() {

	echo "updating LTP files"
	if ! is_ltp_latest; then
		install_ltp
	fi
}

compile_tests() {
	cd "${LTP_DIR}"
	
	./configure CC="${CC}" --prefix="${BINARIES_DIR}"
	gmake "-j$(sysctl -n hw.ncpu)" CC="${CC}"
	gmake install "-j$(sysctl -n hw.ncpu)" CC="${CC}"

	cd "${BASE_DIR}"
	return
}

recreate_logs_dirs() { 

	clean_logs 

	for syscall in "${SYSCALL_DIR}"/*/; do
		basename="$(basename "${syscall}")"
		touch "${LOGS_DIR}/${basename}"
	done
}

# Some tests requeire args to be passed in the cli
# this funcion takes the name of the test and returns
# its args
get_test_args() {
		
	runtest_file="${BINARIES_DIR}/runtest/syscalls"

	args="$(grep "$1" "${runtest_file}" |
			sed "s/$1 *//g")"

	echo "${args}"
}

# 
run_tests() {

	for syscall in "${SYSCALL_DIR}"/*/; do
		basename="$(basename "${syscall}")"
		
		bin_dir="${BINARIES_DIR}/testcases/bin"
		output_file="${LOGS_DIR}/${basename}"

		for syscall_test in "${bin_dir}/${basename}"*; do
			
			test_name="$(basename "${syscall_test}")"
			args="$(get_test_args "${test_name}")"

			{
				echo "==================================================",
				echo "    ${test_name}",
				echo "==================================================",
			} >> "${output_file}"

			echo "syscall_test: ${syscall_test}"

			if [ -z "${args}" ]; then
				"${syscall_test}" 2>&1 | tee -a "${output_file}" || true
			else 
				"${syscall_test}" "${args}" 2>&1 | tee -a "${output_file}" || true
			fi
		done
	done
}


main() {
	for arg in "$@"; do
		if [ "${arg}" = "--update" ]; then
			update_ltp
		elif [ "${arg}" = "--force-reinstall" ]; then
			install_ltp
		elif [ "${arg}" = "--clean" ]; then
			clean
		fi
	done

	if is_empty_dir "${LTP_DIR}"; then 
		install_ltp
	fi

	if is_empty_dir "${BINARIES_DIR}"; then 
		compile_tests
	fi

	recreate_logs_dirs 
	run_tests 
}

main "$@"
