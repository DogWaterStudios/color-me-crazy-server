# Color Me Crazy! dedicated server

The dedicated server for [Color Me Crazy!](https://dogwaterstud.io/colormecrazy/), a co-op paint-by-numbers game by
Dog Water Studios. A server keeps a studio's gallery up for everyone: up to 64 painters join it by address. Nothing
lists servers, so you give your players the address yourself.

```
docker run -dit --name colormecrazy --restart unless-stopped -p 7777:7777/udp -p 7778:7778/udp \
  -v cmc-saved:/server/ColorMeCrazy/Saved dogwaterstudios/colormecrazy -NoUPnP
docker attach colormecrazy
```

The first start asks a few questions in the console: the server's name, passwords and rules. Answer them, then press
Ctrl+P then Ctrl+Q to leave it running. Or use [compose.yaml](compose.yaml) (`docker compose up -d`), which skips the
questions; ask them later by typing `setup` in the console.

The image is also on GitHub's registry as `ghcr.io/dogwaterstudios/colormecrazy`. It is Linux x86-64 only.

## Match the players' build

A server turns away any painter whose game is on another build. `latest` is the build the stores have now. Each build
also has its own tag (its build number, as on the game's front end), so a server can stay on one build:
`dogwaterstudios/colormecrazy:741`. When the game updates, pull again and recreate the container:

```
docker pull dogwaterstudios/colormecrazy
docker stop -t 60 colormecrazy && docker rm colormecrazy
```

Then run it again with the same `docker run` line. The studio lives in the volume, so it stays.

## Running it

- **The network**: forward UDP 7777 on your router to this machine. Players type its public address (`host:7777`) in the
  game's Join box. Docker's NAT keeps the server from asking the router itself, hence `-NoUPnP`. On a Linux host,
  `--network host` (in place of `-p`) puts the server straight on the machine's network, where it forwards the port by
  UPnP and checks it can be reached. For another outside port, map it (`-p 27015:7777/udp`) and add
  `-PublicAddress=<host>:27015`.
- **Server queries**: UDP 7778 (the game port + 1) answers Steam's server queries (A2S_INFO, A2S_PLAYER) for status
  tools and hosting panels: the name, map, build, painters and cap, and whether a join password is set. Painters are
  listed by name (rude words starred) to anyone who asks; `-NoQuery` keeps them private. `-QueryPort=` picks another port, `-NoQuery` turns it off; drop `-p 7778:7778/udp` if
  nothing reads it. There is no RCON: the console is stdin.
- **Two servers on one host** need their own ports, two apart (`-p 7779:7779/udp -p 7780:7780/udp` with `-port=7779`), or
  the first one's query port is the second one's game port.
- **The console** is `docker attach colormecrazy`. Type `help` for the commands: status, rules, `set <rule> <value>`,
  `password`, `adminpassword`, `say`, `backup`, `import`, `restart`, `quit`.
- **Claim it**: with no admin password, the first player to arrive can set the server up from the game. Set one with
  `adminpassword` in the console, or add `-NoClaim`. A password typed in the console stays off the command line.
- **Stopping**: `docker stop -t 60 colormecrazy` saves and quits. The server restarts itself after a crash. With
  `--restart unless-stopped` it also comes back after a reboot, and after the console's `quit`, so stop it with
  `docker stop`.
- **Saved** (the volume) holds everything the server keeps: the studio, its gallery, the rules and the logs. Back it up
  with the console's `backup`, or copy the volume. A host folder works too:
  `-v /srv/cmc:/server/ColorMeCrazy/Saved`, owned by uid 1000.
- **Bringing a player's studio**: mount their `Saved` folder (`-v /home/ada/Saved:/import:ro`), then type `import /import`
  in the console.
- **Hardening**: the server needs no capabilities, so `--cap-drop ALL --security-opt no-new-privileges` can go on the
  run line.

## The connection is encrypted

Every join and the session after it are encrypted, passwords included. On its first start the server makes a signing
key, `Server/server_key.bin` in the volume. The console prints that key's fingerprint at start and with `network`:
`Fingerprint:   ABCD-EFGH-JKMN-PQRS`.

A player's game remembers the key the first time it joins your address, and refuses the address if the key ever
changes, like SSH. To be sure from the first join, give players the address with the fingerprint after a `#`:
`paint.example.com:7777#ABCD-EFGH-JKMN-PQRS`.

- **Keep the volume.** Recreating the container is fine: the key lives in the volume. A new volume makes a new key, and
  every player who joined before is refused until they use the address with the new fingerprint.
- **Never share the key.** Whoever holds it can pass for your server. Back it up with the rest of the volume.
- **Keep the logs private.** The engine writes each join request, password included, into `Logs` in the volume.

## Options

Arguments after the image name go to the server. Each one wins over the saved rules at every start.

| Flag | What it does |
|---|---|
| `-ServerName=` | Name shown to players on arrival |
| `-Welcome=` | One welcome line |
| `-Password=` / `-NoPassword` | Join password, or none |
| `-AdminPassword=` / `-NoAdminPassword` | Admin password, which opens the in-game *Server* screen for house rules |
| `-MaxPlayers=` | Player cap, 2 to 64 |
| `-PointsMultiplier=` | Wage multiplier: 0 pays nothing, otherwise 0.5 to 10 |
| `-ClockMultiplier=` | Multiplies every round's clock, 0.25 to 4 |
| `-EarlyFinishBonus=` | Extra wage for finishing with clock left, 0 to 2 |
| `-UntimedOnly`, `-AllDoorsOpen`, `-BenchFree` | Yes/no house rules; `=0` turns one off |
| `-StandardRules` | Every scoring rule back to standard |
| `-NoSetup` | Skip the first start's questions |
| `-NoClaim` | Nobody can set the server up from the game while it has no admin password |
| `-NoUPnP` | Don't ask the router to forward the port |
| `-NoNetCheck` | Don't look up this server's public address |
| `-PublicAddress=host[:port]` | The address players type, when it isn't this machine's |
| `-QueryPort=` | The server query port (A2S), default the game port + 1; `0` turns it off |
| `-NoQuery` | Answer no server queries |
| `-FullLog` | Show the engine's whole log, not only the server's own lines |

Voice chat needs no setup. The server and its players need to reach the internet (Epic Online Services).

## What's in this repository

`Dockerfile` and `run_server.sh` are what the image is built from, around the packaged server. They are here so you can
see what you run. The server itself is not open source. Dog Water Studios publishes the image; issues and questions go
to [our Discord](https://discord.gg/PGk2qtamgj).

## Third-party software

The image is built on Debian (`debian:bookworm-slim`, with `ca-certificates`) and runs under
[tini](https://github.com/krallin/tini) (MIT). The server is built with Unreal Engine and uses the Epic Online Services
SDK. Their notices are in `/server/NOTICES.txt` in the image.
