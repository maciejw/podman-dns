FROM docker.io/library/alpine:3.23
RUN apk add --no-cache unbound
COPY unbound.conf /etc/unbound/podman.conf
COPY dev.internal.zone /etc/unbound/dev.internal.zone
# Podman puts appnet's DNS server in the container's resolv.conf.
CMD awk '$1 == "nameserver" { print "forward-addr:", $2; found=1 } END { exit !found }' /etc/resolv.conf > /tmp/podman-upstreams.conf && exec unbound -d -c /etc/unbound/podman.conf
