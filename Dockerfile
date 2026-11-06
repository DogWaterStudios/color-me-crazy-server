# The Linux dedicated server as a container. The build context is a packaged LinuxServer folder
# (tools/package_server.ps1 -Platform Linux), not the repo:
#   docker build -f tools/server/Dockerfile -t colormecrazy-server "../Packaged Builds/BroadStrokes/LinuxServer"
#   docker run -dit --name cmc --restart unless-stopped -p 7777:7777/udp -v cmc-saved:/server/ColorMeCrazy/Saved colormecrazy-server
# Arguments after the image name go to the server (-ServerName=, -AdminPassword=, ...), as they do to run_server.sh.
# The server needs no capability (a UDP port above 1024, nothing setuid), so --cap-drop ALL --security-opt no-new-privileges
# may go on the run line; neither was tried here. --read-only is untested: Unreal writes under $HOME and /tmp, not only Saved.
# docker attach cmc is the operator console (Ctrl+P Ctrl+Q leaves it running); docker stop saves and quits (-t 60 for a big
# gallery). docs/dedicated-server.md, "In a container", is the operator's guide.
# The base is a moving tag. For an image that builds the same again, pin its digest once (docker pull debian:bookworm-slim,
# then docker inspect --format '{{index .RepoDigests 0}}' debian:bookworm-slim) and use that here: FROM debian:bookworm-slim@sha256:...
FROM debian:bookworm-slim

# The server links its own C++ runtime; it needs glibc, and certificates for Epic's and our telemetry's HTTPS. tini passes
# docker stop's SIGTERM to the server under run_server.sh's loop (-g: the whole group), so it saves before it goes.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates tini \
	&& rm -rf /var/lib/apt/lists/*

# Unreal refuses to run as root.
RUN useradd --create-home --uid 1000 painter
COPY --chown=painter:painter . /server
RUN chmod +x /server/ColorMeCrazyServer.sh /server/run_server.sh \
		/server/ColorMeCrazy/Binaries/Linux/ColorMeCrazyServer-Linux-Shipping \
	&& mkdir -p /server/ColorMeCrazy/Saved \
	&& chown painter:painter /server/ColorMeCrazy/Saved

USER painter
WORKDIR /server
# The studio, rules, gallery, logs: everything the server keeps (docs/dedicated-server.md, "What is in Saved/").
VOLUME /server/ColorMeCrazy/Saved
ENV PORT=7777
# The game, and the server query (A2S) on the game port + 1.
EXPOSE 7777/udp 7778/udp
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/server/run_server.sh"]
