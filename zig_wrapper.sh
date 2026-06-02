#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "${PROGRAM}" in
ar | *-ar)
	case "${ZIG_TARGET:-}" in
	*-macos* | *-maccatalyst* | *-darwin* | *-ios* | *-tvos* | *-watchos*)
		exec ${ZIG_EXE} ar --format=darwin "$@" ;;
	esac
	exec ${ZIG_EXE} ar "$@" ;;
dlltool | *-dlltool) exec ${ZIG_EXE} dlltool "$@" ;;
lib | *-lib)         exec ${ZIG_EXE} lib "$@" ;;
ranlib | *-ranlib)   exec ${ZIG_EXE} ranlib "$@" ;;
objcopy | *-objcopy) exec ${ZIG_EXE} objcopy "$@" ;;
objdump | *-objdump) exec ${ZIG_EXE} objdump "$@" ;;
rc | windres | *-rc | *-windres) exec ${ZIG_EXE} rc "$@" ;;
strip | *-strip)
	tmpfile="$1$(mktemp -d --dry-run .strip.XXXX)"
	${ZIG_EXE} objcopy -S "$1" "${tmpfile}" || true
	if [ $? -eq 0 ] && [ -s "${tmpfile}" ] && [ "$(file -b --mime-type "${tmpfile}")" = "application/x-executable" ]; then
		exec mv "${tmpfile}" "$1"
	else
		echo "WARNING: unable to strip $1"
		rm "${tmpfile}" || true
	fi
	;;
*cc | *c++ | *g++ | *clang | *clang++)
	if ! test "${ZIG_TARGET+1}"; then
		case "${PROGRAM}" in
		cc | c++ | gcc | g++ | clang | clang++) ;;  # leave unset as zig detects native target + libc
		*-cc)      ZIG_TARGET="${PROGRAM%-cc}" ;;
		*-gcc)     ZIG_TARGET="${PROGRAM%-gcc}" ;;
		*-c++)     ZIG_TARGET="${PROGRAM%-c++}" ;;
		*-g++)     ZIG_TARGET="${PROGRAM%-g++}" ;;
		*-clang)   ZIG_TARGET="${PROGRAM%-clang}" ;;
		*-clang++) ZIG_TARGET="${PROGRAM%-clang++}" ;;
		esac
	fi

	## Zig doesn't properly handle these flags so we have to rewrite/ignore.
	## None of these affect the actual compilation target.
	## https://github.com/ziglang/zig/issues/9948
	for argv in "$@"; do
		case "${argv}" in
		-Wp,-MD,*) set -- "$@" "-MD" "-MF" "$(echo "${argv}" | sed 's/^-Wp,-MD,//')" ;;
		-Wl,--warn-common | -Wl,--verbose | -Wl,-Map,* | -Wl,-sectcreate,*) ;;
		--target=*) ;;
		*) set -- "$@" "${argv}" ;;
		esac
		shift
	done

	# Determine zig subcommand: c++ for anything that's a C++ compiler, cc otherwise
	case "${PROGRAM}" in
	*c++ | *g++ | *clang++) ZIG_CMD=c++ ;;
	*)                      ZIG_CMD=cc  ;;
	esac

	if [ -n "${ZIG_TARGET:-}" ]; then
		set -- "${ZIG_CMD}" --target="${ZIG_TARGET}" "$@"
	else
		set -- "${ZIG_CMD}" "$@"
	fi

	exec ${ZIG_EXE} "${@}"
	;;
*)
	if test -h "$0"; then
		exec "$(dirname "$0")/$(readlink "$0")" "$@"
	fi
	echo "ERROR: '${PROGRAM}' is not supported by this zig wrapper" >&2
	exit 1
	;;
esac
