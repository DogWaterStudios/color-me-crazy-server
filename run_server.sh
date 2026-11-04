#!/usr/bin/env bash
# Runs the Color Me Crazy! dedicated server and starts it again if it crashes or asks to restart.
# Put this next to ColorMeCrazyServer.sh. Extra arguments go straight to the server, and win over rules.json every start:
#   ./run_server.sh -ServerName="My Studio" -Password=letmein -AdminPassword=hunter2 -Welcome="Paint nice" -MaxPlayers=16
# The first start at a keyboard asks a few questions instead (name, passwords, rules, bringing in your studio);
# type help in the server's terminal for everything else.
# Settings, from the environment:
#   PORT=7778 ./run_server.sh      UDP port (default 7777)
#   SUFFIX=B ./run_server.sh       a second server on this machine: its own Saved_B folder (studio, rules, wallets)
# A clean exit (the console's quit) ends the loop; so does Ctrl+C or a kill. The console's restart and import start it again.
# A crash waits 5 seconds and starts it again; a server that keeps crashing soon after it starts (five times in a row, each
# within a minute of its start) waits twice as long each time, up to ten minutes, and a run that lasts a minute starts over.
cd "$(dirname "$0")" || exit 1
PORT="${PORT:-7777}"
EXTRA=()
SAVED=ColorMeCrazy/Saved
if [[ -n "${SUFFIX:-}" ]]; then
	EXTRA+=("-saveddirsuffix=$SUFFIX")
	SAVED="ColorMeCrazy/Saved_$SUFFIX"
fi

# The binary itself, not Unreal's ColorMeCrazyServer.sh beside it: that wrapper is a plain sh that dies on Ctrl+C or a stop
# and leaves the server behind. Ctrl+C, or a stop from systemd or docker (tini -g), reaches the server; this loop stays to
# see it out, so whatever runs it (a container's first process) does not end until the server has saved and quit.
SERVER=ColorMeCrazy/Binaries/Linux/ColorMeCrazyServer-Linux-Shipping
chmod +x "$SERVER" 2>/dev/null
stopping=
trap 'stopping=1' TERM INT
quick=0 # crashes in a row that came within a minute of a start
pause=5

while [[ -z $stopping ]]; do
	started=$SECONDS
	"./$SERVER" ColorMeCrazy L_Gallery -port="$PORT" "${EXTRA[@]}" "$@"
	code=$?
	if [[ -n $stopping ]]; then
		echo "Server stopped ($code)."
		exit 0
	fi
	if [[ -f "$SAVED/Server/restart" ]]; then
		rm -f "$SAVED/Server/restart"
		echo "[$(date '+%F %T')] Restarting."
		continue
	fi
	# 0 is a clean quit; 130 and 143 are Ctrl+C and SIGTERM.
	if [[ $code == 0 || $code == 130 || $code == 143 ]]; then
		echo "Server exited ($code)."
		exit 0
	fi
	if (( SECONDS - started < 60 )); then quick=$((quick + 1)); else quick=0; fi
	if (( quick >= 5 )); then pause=$((pause * 2 > 600 ? 600 : pause * 2)); else pause=5; fi
	echo "[$(date '+%F %T')] Server stopped with code $code. Starting again in $pause seconds (Ctrl+C to stop)."
	# Waited for in the background, so a stop that comes meanwhile is heard at once, not when the wait is over.
	sleep "$pause" &
	wait $!
	kill $! 2>/dev/null
done
# A stop that came while it waited to start again (the loop's test is what sees it).
echo "Stopped before the server started again."
