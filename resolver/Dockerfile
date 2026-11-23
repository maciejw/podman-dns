FROM docker.io/library/buildpack-deps:26.04-curl
ARG APT_SOURCES_FILE=ubuntu.sources
RUN rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
COPY ${APT_SOURCES_FILE} /etc/apt/sources.list.d/sample.sources
RUN apt-get update \
    && apt-get install -y --no-install-recommends unbound \
    && rm -rf /var/lib/apt/lists/*
COPY unbound.conf /etc/unbound/podman.conf
COPY dev.internal.zone /etc/unbound/dev.internal.zone
# Podman puts appnet's DNS server in the container's resolv.conf.
CMD awk '$1 == "nameserver" { print "forward-addr:", $2; found=1 } END { exit !found }' /etc/resolv.conf > /tmp/podman-upstreams.conf && exec unbound -d -c /etc/unbound/podman.conf
