FROM alpine:3.22

RUN apk add --no-cache squid socat

COPY squid.conf /etc/squid/squid.conf

USER squid
EXPOSE 3128
CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]
