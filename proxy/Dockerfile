FROM alpine:3.22

RUN apk add --no-cache iproute2 nftables setpriv socat squid

COPY proxy/squid.conf /etc/squid/squid.conf
COPY firewall/sandbox-init /usr/local/bin/sandbox-init

# Starts as root only so sandbox-init can load the firewall; it then runs the
# command unprivileged. devport overrides the role and user.
EXPOSE 3128
ENTRYPOINT ["sandbox-init", "proxy", "squid"]
CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]
