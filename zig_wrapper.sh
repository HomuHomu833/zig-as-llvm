#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "${PROGRAM}" in
ar | *-ar) exec ${ZIG_EXE} ar "$@" ;;
dlltool | *-dlltool) exec ${ZIG_EXE} dlltool "$@" ;;
lib | *-lib) exec ${ZIG_EXE} lib "$@" ;;
ranlib | *-ranlib) exec ${ZIG_EXE} ranlib "$@" ;;
objcopy | *-objcopy) exec ${ZIG_EXE} objcopy "$@" ;;
ld.lld | *ld.lld | ld | *-ld) exec ${ZIG_EXE} ld.lld "$@" ;;
rc) exec $ZIG_EXE rc "$@" ;;
strip | *-strip)
	tmpfile="$1$(mktemp -d --dry-run .strip.XXXX)"
	zig objcopy -S "$1" "${tmpfile}"
	exec mv "${tmpfile}" "$1"
	;;
*cc | *c++)
	if ! test "${ZIG_TARGET+1}"; then
		case "${PROGRAM}" in
		cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
		*) ZIG_TARGET=$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/') ;;
		esac
	fi

	# Remove any --target=* argument from the list of arguments
	set -- $(echo "$@" | sed 's/--target=[^ ]*//g')

	## Zig doesn't properly handle these flags so we have to rewrite/ignore.
	## None of these affect the actual compilation target.
	## https://github.com/ziglang/zig/issues/9948
	for argv in "$@"; do
		case "${argv}" in
		-Wp,-MD,*) set -- "$@" "-MD" "-MF" "$(echo "${argv}" | sed 's/^-Wp,-MD,//')" ;;
		-Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*) ;;
		*) set -- "$@" "${argv}" ;;
		esac
		shift
	done

	# Add the target argument back if necessary, now handled correctly
	case "${PROGRAM}" in
	*cc) set -- cc --target="${ZIG_TARGET}" "$@" ;;
	*c++) set -- c++ --target="${ZIG_TARGET}" "$@" ;;
	esac

	exec ${ZIG_EXE} "${@}"
	;;
*)
	if test -h "$0"; then
		exec "$(dirname "$0")/$(readlink "$0")" "$@"
	fi
	;;
esac
