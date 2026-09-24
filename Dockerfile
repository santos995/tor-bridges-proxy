ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION}

ENV TZ=Europe/Moscow

# Install logrotate for log management
RUN echo '@edgecommunity https://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
    apk -U upgrade && \
    apk -v add --no-cache \
        tor@edgecommunity \
        obfs4proxy@testing \
        bash \
        curl \
        nginx \
        php82-fpm \
        php82-session \
        apache2-utils \
        logrotate && \
    rm -rf /var/cache/apk/* && \
    chmod 700 /var/lib/tor && \
    mkdir -p /var/www /var/log/nginx /var/log/php-fpm /etc/logrotate.d && \
    chown tor:root /var/www /var/log/tor && \
    chmod 755 /var/log/tor

# Copy application files
COPY --chown=tor:root torrc /etc/tor/
COPY --chown=tor:root bridges.txt /etc/tor/
COPY --chown=tor:root VERSION /srv/
COPY --chown=root:root logrotate/tor.conf /etc/logrotate.d/tor
COPY --chown=root:root logrotate/nginx.conf /etc/logrotate.d/nginx
COPY --chown=root:root logrotate/php-fpm.conf /etc/logrotate.d/php-fpm
COPY --chown=tor:root nginx.conf /etc/nginx/
COPY --chown=tor:root php-fpm.conf /etc/php82/
COPY --chown=tor:root www.conf /etc/php82/php-fpm.d/
COPY --chown=tor:root bridges.sh /srv/
COPY --chown=tor:root pwd.sh /srv/
COPY --chown=tor:root tor-bridges-proxy /srv/
COPY --chown=tor:root webroot/ /var/www/

RUN chmod +x /srv/bridges.sh && \
    chmod +x /srv/pwd.sh && \
    chmod +x /srv/tor-bridges-proxy

HEALTHCHECK --timeout=10s --start-period=60s \
CMD curl --fail --socks5-hostname 127.0.0.1:9150 -I -L 'https://www.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/' || exit 1

USER tor

EXPOSE 9053/udp 9150/tcp 9151/tcp

CMD ["/srv/tor-bridges-proxy"]
