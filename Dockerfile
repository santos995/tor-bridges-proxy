# Tor Bridges Proxy Dockerfile
# Supports: obfs4, snowflake, meek, webtunnel (via lyrebird)
ARG ALPINE_VERSION=3.19
ARG TOR_EXPERT_BUNDLE_VERSION=15.0.23

FROM alpine:${ALPINE_VERSION}

ENV TZ=Europe/Moscow

# Install base packages + download Tor Expert Bundle (includes lyrebird with all PTs)
# lyrebird supports: obfs4, snowflake, meek, webtunnel
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
        logrotate \
        xz \
        tar && \
    rm -rf /var/cache/apk/* && \
    chmod 700 /var/lib/tor && \
    mkdir -p /var/www /var/log/nginx /var/log/php-fpm /etc/logrotate.d /usr/local/bin && \
    chown tor:root /var/www /var/log/tor && \
    chmod 755 /var/log/tor && \
    # Download Tor Expert Bundle with lyrebird (obfs4+snowflake+meek+webtunnel)
    curl -L --fail -o /tmp/tor-expert-bundle.tar.gz "https://dist.torproject.org/torbrowser/${TOR_EXPERT_BUNDLE_VERSION}/tor-expert-bundle-linux-x86_64-${TOR_EXPERT_BUNDLE_VERSION}.tar.gz" && \
    # Extract lyrebird from the bundle
    tar -xzf /tmp/tor-expert-bundle.tar.gz -C /tmp/ && \
    mv /tmp/tor/pluggable_transports/lyrebird /usr/local/bin/lyrebird && \
    chmod +x /usr/local/bin/lyrebird && \
    # Create symlinks for backward compatibility
    ln -sf /usr/local/bin/lyrebird /usr/bin/obfs4proxy && \
    ln -sf /usr/local/bin/lyrebird /usr/bin/snowflake-client && \
    ln -sf /usr/local/bin/lyrebird /usr/bin/meek-client && \
    # Clean up
    rm -rf /tmp/tor /tmp/tor-expert-bundle.tar.gz

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
    chmod +x /usr/local/bin/lyrebird && \
    chmod +x /usr/bin/obfs4proxy && \
    chmod +x /usr/bin/snowflake-client && \
    chmod +x /usr/bin/meek-client

HEALTHCHECK --timeout=10s --start-period=60s \
CMD curl --fail --socks5-hostname 127.0.0.1:9150 -I -L 'https://www.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/' || exit 1

USER tor

EXPOSE 9053/udp 9150/tcp 9151/tcp

CMD ["/srv/tor-bridges-proxy"]
