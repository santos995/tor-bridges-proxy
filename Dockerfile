# Multi-stage build: first compile pluggable transports, then package
ARG ALPINE_VERSION=3.19

# ─── Builder stage ───────────────────────────────────────────────────────────
FROM alpine:${ALPINE_VERSION} AS builder

ENV TZ=Europe/Moscow

# Install build dependencies
RUN apk add --no-cache \
        git \
        go \
        ca-certificates \
        curl \
        make

# Clone and build obfs4proxy (obfs4 transport)
# https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/obfs4.git
RUN git clone --depth 1 https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/obfs4.git /src/obfs4 && \
    cd /src/obfs4/obfs4proxy && \
    go build -ldflags="-s -w" -o /usr/bin/obfs4proxy

# Clone and build snowflake-client (WebRTC transport)
# https://gitlab.torproject.org/tpo/anti-censorship/web/snowflake.git
RUN git clone --depth 1 https://gitlab.torproject.org/tpo/anti-censorship/web/snowflake.git /src/snowflake && \
    cd /src/snowflake/client && \
    go build -ldflags="-s -w" -o /usr/bin/snowflake-client

# Clone and build meek-client (domain fronting transport)
# https://git.torproject.org/pluggable-transports/meek.git
RUN git clone --depth 1 https://git.torproject.org/pluggable-transports/meek.git /src/meek && \
    cd /src/meek && \
    go build -ldflags="-s -w" -o /usr/bin/meek-client

# ─── Final stage ─────────────────────────────────────────────────────────────
FROM alpine:${ALPINE_VERSION}

ENV TZ=Europe/Moscow

# Add edge/community for meek-server (optional, for advanced users)
RUN echo '@edgecommunity https://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    apk -U upgrade && \
    apk -v add --no-cache \
        tor \
        bash \
        curl \
        nginx \
        php81-fpm \
        php81-session \
        apache2-utils \
        logrotate && \
    rm -rf /var/cache/apk/* && \
    chmod 700 /var/lib/tor && \
    mkdir -p /var/www /var/log/nginx /var/log/php-fpm /etc/logrotate.d && \
    chown tor:root /var/www /var/log/tor && \
    chmod 755 /var/log/tor

# Copy compiled pluggable transports from builder
COPY --from=builder /usr/bin/obfs4proxy /usr/bin/obfs4proxy
COPY --from=builder /usr/bin/snowflake-client /usr/bin/snowflake-client
COPY --from=builder /usr/bin/meek-client /usr/bin/meek-client

# Copy application files
COPY --chown=tor:root torrc /etc/tor/
COPY --chown=tor:root bridges.txt /etc/tor/
COPY --chown=tor:root VERSION /srv/
COPY --chown=root:root logrotate/tor.conf /etc/logrotate.d/tor
COPY --chown=root:root logrotate/nginx.conf /etc/logrotate.d/nginx
COPY --chown=root:root logrotate/php-fpm.conf /etc/logrotate.d/php-fpm
COPY --chown=tor:root nginx.conf /etc/nginx/
COPY --chown=tor:root php-fpm.conf /etc/php81/
COPY --chown=tor:root www.conf /etc/php81/php-fpm.d/
COPY --chown=tor:root bridges.sh /srv/
COPY --chown=tor:root pwd.sh /srv/
COPY --chown=tor:root tor-bridges-proxy /srv/
COPY --chown=tor:root webroot/ /var/www/

RUN chmod +x /srv/bridges.sh && \
    chmod +x /srv/pwd.sh && \
    chmod +x /srv/tor-bridges-proxy && \
    chmod +x /usr/bin/obfs4proxy && \
    chmod +x /usr/bin/snowflake-client && \
    chmod +x /usr/bin/meek-client

HEALTHCHECK --timeout=10s --start-period=60s \
CMD curl --fail --socks5-hostname 127.0.0.1:9150 -I -L 'https://www.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/' || exit 1

USER tor

EXPOSE 9053/udp 9150/tcp 9151/tcp

CMD ["/srv/tor-bridges-proxy"]
