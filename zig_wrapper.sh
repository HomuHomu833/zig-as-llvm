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
    zig objcopy -S "$1" "${tmpfile}" || true
    if [ $? -eq 0 ] && [ -s "${tmpfile}" ] && \
       [ "$(file -b --mime-type "${tmpfile}")" = "application/x-executable" ]; then
        exec mv "${tmpfile}" "$1"
    else
        echo "WARNING: unable to strip $1"
        rm -f "${tmpfile}" || true
    fi
    ;;
*cc | *c++)
    if [ -z "${ZIG_TARGET+x}" ]; then
        echo "ZIG_TARGET is missing."
        exit 127
    fi

    new_args=""
    skip_next=0
    for arg in "$@"; do
        if [ "$skip_next" -eq 1 ]; then
            skip_next=0
            continue
        fi
        case "$arg" in
            -Wp,-MD,*)
                file=$(echo "$arg" | sed 's/^-Wp,-MD,//')
                new_args="$new_args -MD -MF $file"
                ;;
            -Wl,--warn-common|-Wl,--verbose|-Wl,-Map,*|-Wl,-sectcreate,*)
                ;;
            --target=*|-target=*)
                ;;
            -target)
                skip_next=1
                ;;
            *)
                new_args="$new_args $arg"
                ;;
        esac
    done

    # shellcheck disable=SC2086
    set -- $new_args

    case "${PROGRAM}" in
        *cc) set -- cc --target="${ZIG_TARGET}" "$@" ;;
        *c++) set -- c++ --target="${ZIG_TARGET}" "$@" ;;
    esac

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if [ -h "$0" ]; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac
