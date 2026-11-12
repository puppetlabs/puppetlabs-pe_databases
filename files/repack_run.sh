#!/bin/bash
# Runs a command, stops it with SIGINT when the wrapper receives SIGINT or
# SIGTERM, always runs a cleanup command after it has ended, and exits with the
# command's exit status.

usage() {
  cat <<'EOF'
Usage: repack_run.sh <cleanup command> [args ...] -- <command> [args ...]

Starts <command> and waits for it to end. When the wrapper receives SIGINT or
SIGTERM, <command> is stopped with SIGINT (also when the signal arrives before
<command> has started). When it has ended, for whatever reason, the cleanup
command is run once, with SIGINT and SIGTERM ignored.

Exit codes:
  2  usage error, nothing was run (a command that itself exits with 2 cannot
     be told apart from a usage error)
  otherwise the exit status of <command>; 128 + the signal number when
  <command> was killed by a signal. A failing cleanup command is reported on
  stderr and does not change the exit status.
EOF
}

cleanup=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  cleanup+=("$1")
  shift
done
if [ $# -lt 2 ] || [ ${#cleanup[@]} -eq 0 ] || [ -z "${cleanup[0]}" ]; then
  usage >&2
  echo "repack_run: a cleanup command, -- and a command are required" >&2
  exit 2
fi
shift

child=
pending=
self_cmdline=$({ tr '\0' ' ' <"/proc/$$/cmdline"; } 2>/dev/null)

# A freshly forked child runs the wrapper's signal handlers until it has
# executed the command, and a signal it receives before that is lost. Wait
# (at most about 3 s) until its command line differs from the wrapper's. When
# /proc cannot be read that wait is not possible, so pause briefly instead.
stop_child() {
  local i=0
  [ -z "$self_cmdline" ] && sleep 0.2
  while [ "$i" -lt 300 ] && [ -r "/proc/$child/cmdline" ] &&
    [ "$({ tr '\0' ' ' <"/proc/$child/cmdline"; } 2>/dev/null)" = "$self_cmdline" ]; do
    sleep 0.01
    i=$((i + 1))
  done
  kill -s INT "$child" 2>/dev/null
}

# shellcheck disable=SC2329 # called from the traps below
forward() {
  echo "repack_run: received SIG$1, stopping ${child:-the command once it has started} with SIGINT" >&2
  if [ -n "$child" ]; then
    stop_child
  else
    pending=yes
  fi
}
trap 'forward INT' INT
trap 'forward TERM' TERM

# A non-interactive bash starts background commands with SIGINT ignored, and
# bash 4.2 cannot undo that in the child. Job control during the launch keeps
# SIGINT at its default in the child.
set -m
"$@" &
child=$!
set +m
if [ -n "$pending" ]; then
  stop_child
fi

# wait returns early with a status above 128 when a trapped signal arrives, so
# wait again until the child has really ended.
while :; do
  wait "$child"
  rc=$?
  [ "$rc" -gt 128 ] || break
  if kill -0 "$child" 2>/dev/null; then
    continue
  fi
  # The child ended while the trap ran: ask wait for its status once more and
  # use it only if it is a real exit status (bash 4.4 can return -1 here, and
  # 127 means the status is not known).
  wait "$child"
  r2=$?
  if [ "$r2" -ge 0 ] && [ "$r2" -le 255 ] && [ "$r2" -ne 127 ]; then
    rc=$r2
  fi
  break
done

trap '' INT TERM
echo "repack_run: command exited with status $rc, running the cleanup command" >&2
"${cleanup[@]}"
crc=$?
if [ "$crc" -ne 0 ]; then
  echo "repack_run: cleanup command exited with status $crc" >&2
fi
exit "$rc"
