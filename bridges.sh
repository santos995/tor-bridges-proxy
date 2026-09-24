#!/bin/bash

# Change bridge
BRIDGES="/etc/tor/bridges.txt"
LOG_FILE="/var/log/tor/notices.log"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [bridges.sh] $1" >> "$LOG_FILE"
}

log "Starting bridge configuration..."

# Clear log with timestamp
printf "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] >_ created by ZeroChaos. Visit site: https://zerolab.net\n" > "$LOG_FILE"

# Build torrc from scratch
cat > /etc/tor/torrc <<'TORRC'
HardwareAccel 1
DataDirectory /var/lib/tor
ExcludeExitNodes {us},{ca},{cn},{hk},{jp},{kr},{tw},{ru},{ua},{by},{kz},{in},{af},{aq},{ar},{au},{bs},{bh},{bb},{bz},{bo},{bw},{br},{bn},{bf},{bi},{kh},{cm},{cv},{ky},{cf},{td},{cl},{co},{km},{cg},{cd},{ck},{cr},{ci},{cu},{dj},{dm},{do},{ec},{eg},{sv},{gq},{et},{fk},{fo},{fj},{ga},{gm},{gh},{gi},{gl},{gd},{gp},{gu},{gt},{gn},{gw},{gy},{ht},{hn},{id},{ir},{iq},{il},{jm},{jo},{ke},{ki},{kp},{kg},{lb},{ls},{lr},{ly},{mo},{mg},{mw},{my},{mv},{ml},{mt},{mh},{mq},{mr},{mu},{yt},{mx},{fm},{mn},{ms},{ma},{mz},{mm},{na},{nr},{np},{nc},{nz},{ni},{ne},{ng},{nu},{nf},{mp},{om},{pk},{pw},{ps},{pa},{pg},{py},{pe},{ph},{pr},{qa},{re},{rw},{ws},{st},{sa},{sn},{sc},{sl},{sb},{so},{as},{za},{lk},{kn},{lc},{pm},{vc},{sd},{sr},{sz},{sy},{tj},{tz},{th},{tg},{tk},{to},{tt},{tn},{tr},{tm},{tc},{tv},{ug},{ae},{uy},{vu},{vn},{vi},{wf},{ye},{zm},{zw},{??}
StrictNodes 1
TORRC

# Add dynamic config
echo "Log notice file /var/log/tor/notices.log" >> /etc/tor/torrc
echo "DNSPort 0.0.0.0:9053" >> /etc/tor/torrc
echo "SocksPort 0.0.0.0:9150" >> /etc/tor/torrc

# Parse bridges.txt and configure appropriate transport plugins
# Supported formats:
#   obfs4 <fingerprint> <ip>:<port> <cert> <iat-mode>
#   snowflake <domain>
#   meek_lite <domain> [endpoint-domain]
#   webtunnel <domain> <server-key>
#   dnstt <subdomain>
#
# Lines starting with # are comments (skipped)

if [[ -s ${BRIDGES} ]]; then
    while IFS= read -r LINE; do
        # Skip empty lines and comments
        [[ -z "$LINE" || "$LINE" =~ ^[[:space:]]*# ]] && continue
        
        # Determine bridge type by first token after "Bridge "
        BRIDGE_LINE=$(echo "$LINE" | sed 's/^Bridge[[:space:]]*//')
        FIRST_TOKEN=$(echo "$BRIDGE_LINE" | awk '{print $1}')
        
        case "$FIRST_TOKEN" in
            obfs4)
                echo "ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy" >> /etc/tor/torrc
                echo "Bridge ${LINE}" >> /etc/tor/torrc
                log "Added obfs4 bridge: ${BRIDGE_LINE:0:50}..."
                ;;
            snowflake)
                echo "ClientTransportPlugin snowflake exec /usr/bin/snowflake-client" >> /etc/tor/torrc
                echo "Bridge ${LINE}" >> /etc/tor/torrc
                log "Added snowflake bridge: ${BRIDGE_LINE:0:50}..."
                ;;
            meek_lite)
                echo "ClientTransportPlugin meek exec /usr/bin/meek-client" >> /etc/tor/torrc
                echo "Bridge ${LINE}" >> /etc/tor/torrc
                log "Added meek bridge: ${BRIDGE_LINE:0:50}..."
                ;;
            webtunnel)
                echo "ClientTransportPlugin webtunnel exec /usr/bin/webtunnel" >> /etc/tor/torrc
                echo "Bridge ${LINE}" >> /etc/tor/torrc
                log "Added webtunnel bridge: ${BRIDGE_LINE:0:50}..."
                ;;
            dnstt)
                echo "ClientTransportPlugin dnstt exec /usr/bin/dnstt" >> /etc/tor/torrc
                echo "Bridge ${LINE}" >> /etc/tor/torrc
                log "Added dnstt bridge: ${BRIDGE_LINE:0:50}..."
                ;;
            *)
                # Standard bridge (direct obfs4 format without prefix)
                # Try to detect type from fingerprint pattern
                if echo "$BRIDGE_LINE" | grep -qi "obfs4 "; then
                    echo "ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy" >> /etc/tor/torrc
                    echo "Bridge ${LINE}" >> /etc/tor/torrc
                    log "Added obfs4 bridge: ${BRIDGE_LINE:0:50}..."
                elif echo "$BRIDGE_LINE" | grep -qi "snowflake "; then
                    echo "ClientTransportPlugin snowflake exec /usr/bin/snowflake-client" >> /etc/tor/torrc
                    echo "Bridge ${LINE}" >> /etc/tor/torrc
                    log "Added snowflake bridge: ${BRIDGE_LINE:0:50}..."
                elif echo "$BRIDGE_LINE" | grep -qi "meek_lite "; then
                    echo "ClientTransportPlugin meek exec /usr/bin/meek-client" >> /etc/tor/torrc
                    echo "Bridge ${LINE}" >> /etc/tor/torrc
                    log "Added meek bridge: ${BRIDGE_LINE:0:50}..."
                else
                    echo "Bridge ${LINE}" >> /etc/tor/torrc
                    log "Added standard bridge: ${BRIDGE_LINE:0:50}..."
                fi
                ;;
        esac
    done < ${BRIDGES}
    
    # Enable bridges if any were loaded
    if grep -q "Bridge " /etc/tor/torrc; then
        echo "UseBridges 1" >> /etc/tor/torrc
        log "Bridges enabled"
    fi
else
    log "No bridges configured"
fi

# Restart Tor
log "Restarting Tor with new configuration..."
pkill -TERM tor
sleep 2

# Ensure Tor is stopped
pkill -9 tor 2>/dev/null
sleep 1

/usr/bin/tor -f /etc/tor/torrc &
log "Tor restarted successfully"
