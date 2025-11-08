#!/bin/sh
set -e

# Domain to generate certificate for
DOMAIN="whtest.365cloud.my.id"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"
CHAIN_FILE="${CERT_DIR}/chain.pem"

echo "🔍 Checking SSL certificates for ${DOMAIN}..."

# Check if Let's Encrypt certificates exist
if [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo "✅ SSL certificates found - using Let's Encrypt certificates"
else
    echo "⚠️  SSL certificates not found - generating temporary self-signed certificates"
    echo "   These will be replaced when you run: bash scripts/ssl-setup.sh --standalone"

    # Create directory structure
    mkdir -p "${CERT_DIR}"

    # Generate self-signed certificate valid for 365 days
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "${KEY_FILE}" \
        -out "${CERT_FILE}" \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN}" \
        2>/dev/null

    # Create chain file (copy of cert for self-signed)
    cp "${CERT_FILE}" "${CHAIN_FILE}"

    echo "✅ Temporary self-signed certificate generated"
    echo "📌 Remember to generate real Let's Encrypt certificate after nginx starts:"
    echo "   cd ~/tcra-webhook-tester && bash scripts/ssl-setup.sh --standalone"
fi

# Execute the original nginx entrypoint
echo "🚀 Starting nginx..."
exec /docker-entrypoint.sh "$@"
