#!/bin/sh
#
#	install and compile LTP syscalls testes on NetBSD, using Compat Linux
#
# 	Requirements:
# 	- gmake
# 	- pkgconf
# 	- suse_gcc12-15.5
# 	- curl
# 	- module compat_linux enabled

set -e

# Directory where the script data is stored
DATA_DIR="/var/db/compat_linux_test_project"

# Directory where the LTP tests will be cloned
LTP_DIR="${DATA_DIR}/ltp"

# Base directory for the syscalls subdirectory inside ltp
SYSCALL_DIR="${LTP_DIR}/testcases/kernel/syscalls"

# Directory where compiled tests will be placed
BINARIES_DIR="${DATA_DIR}/bin"
export LTPROOT="${BINARIES_DIR}"
export PATH="${PATH}:${BINARIES_DIR}/testcases/bin"

# Controls the level of verbosity:
# -1 = Silent. Only logs
# 0  = Standard. Only displays only stderr and logs
# 1  = Verbose.  Display stdin, stdout and logs
VERBOSITY=0

# What compiler to use. Default searches for suse_gcc12-15.5
CC="/emul/linux/usr/bin/gcc-12"

# Latest release available for LTP
# Default is an empty string, which raises an error
LTP_RELEASE=""

LTP_VERSION_FILE="${DATA_DIR}/ltp_version"

# Release version of the tests
LTP_URL=""

if ! [ -e "${LTP_VERSION_FILE}" ]; then
	echo 0 > "${LTP_VERSION_FILE}"
fi

# Currently installed LTP version
LTP_CURRENT_VERSION="$(cat ${LTP_VERSION_FILE})"

if ! [ -e "${LTP_DIR}" ]; then
	mkdir "${LTP_DIR}"
fi

if ! [ -e "${BINARIES_DIR}" ]; then
	mkdir "${BINARIES_DIR}"
fi

check_compat_linux() {
	if ! modstat -q compat_linux; then
		echo "Error: Compat Linux is inactive" >&2
		exit 1
	fi
}

get_ltp_url() {
	url="https://github.com/linux-test-project/ltp/releases/download/${LTP_RELEASE}/ltp-full-${LTP_RELEASE}.tar.xz"

	echo "${url}"
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

are_tests_compiled() {

	test_location="${BINARIES_DIR}/testcases/bin/${SYSCALL_NAME}"

	# We only need to find one test, as they are compiled all together
	for t in "${test_location}"[0-9]*; do
    	if [ -e "${t}" ]; then
			return 0
		fi
	done

	return 1
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

	echo "${LTP_RELEASE}" > "${LTP_VERSION_FILE}"
	LTP_URL="$(get_ltp_url)"

	curl -OLs --output-dir "${DATA_DIR}" "${LTP_URL}"
	tar -xf "${DATA_DIR}/ltp-full-${LTP_RELEASE}.tar.xz" -C "${LTP_DIR}" --strip-components=1
	rm "${DATA_DIR}/ltp-full-${LTP_RELEASE}.tar.xz" # no reason to keep the tar
}

compile_setup() {
	cd "${LTP_DIR}"

	case "${VERBOSITY}" in
		-1)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}" \
				CFLAGS="-pthread" LDFLAGS="-static -L${LTP_DIR}/lib -Wl,--whole-archive -lpthread -Wl,--no-whole-archive" \
				>/dev/null 2>&1
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)" \
				>/dev/null 2>&1
			;;
		0)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}" \
				CFLAGS="-pthread" LDFLAGS="-static -L${LTP_DIR}/lib -Wl,--whole-archive -lpthread -Wl,--no-whole-archive" \
				1>/dev/null
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)" \
				1>/dev/null
			;;
		1)
			./configure CC="${CC}" --prefix="${BINARIES_DIR}" \
				CFLAGS="-pthread" LDFLAGS="-static -L${LTP_DIR}/lib -Wl,--whole-archive -lpthread -Wl,--no-whole-archive"
			gmake install -C "${LTP_DIR}/runtest" -j"$(sysctl -n hw.ncpu)"
			;;
	esac
}

compile_tests() {
	cd "${LTP_DIR}"
	runtest_file="${BINARIES_DIR}/runtest/syscalls"

	echo "=> compiling tests"

	if ! [ -e "${runtest_file}" ]; then
		compile_setup
	fi

	case "${VERBOSITY}" in
		-1)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_NAME}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" >/dev/null 2>&1
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_NAME}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" >/dev/null 2>&1
			;;
		0)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_NAME}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" 1>/dev/null
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_NAME}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}" 1>/dev/null
			;;
		1)
			gmake -C "${SYSCALL_DIR}/${SYSCALL_NAME}" -k \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}"
			gmake install -C "${SYSCALL_DIR}/${SYSCALL_NAME}" \
				-j"$(sysctl -n hw.ncpu)" CC="${CC}"
			;;
	esac

	cd "${DATA_DIR}"
	return
}


main() {

	check_compat_linux

	# default for compiling and installing
	VERBOSITY=-1
	force_compile=1

	while [ "$#" -gt 0 ]; do
		arg="$1"

		if [ "${arg}" = "--ltp-version" ]; then
			shift #consumes the arg
			LTP_RELEASE="$1" # uses the next
		elif [ "${arg}" = "--force-compile" ]; then
			force_compile=0
		elif [ "${arg}" = "--verbose" ]; then
			VERBOSITY=1
		elif [ "${arg}" = "--silent" ]; then
			VERBOSITY=-1
		else
			echo "Invalid Option: '${arg}'" >&2
			exit 1
		fi

		shift
	done

	if [ -z "${LTP_RELEASE}" ]; then
		echo "Error: No ltp-version was passed" >&2
		exit 1
	fi

	if ! is_ltp_latest; then
		clean_binaries
		clean_ltp_source
		install_ltp
		compile_tests
	fi

	if ! are_tests_compiled; then
		compile_tests
	fi
}

main "$@"
