#!/bin/sh
# Note: No 'set -e' to allow better error handling

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
    echo ""

    # Install openssl if not available
    if ! command -v openssl >/dev/null 2>&1; then
        echo "📦 Installing openssl..."
        apk add --no-cache openssl
        if [ $? -eq 0 ]; then
            echo "✅ OpenSSL installed"
        else
            echo "❌ Failed to install openssl"
            echo "🚨 Cannot generate certificates - nginx may fail to start"
            exec /docker-entrypoint.sh "$@"
        fi
    else
        echo "✅ OpenSSL already available"
    fi

    # Create directory structure
    echo "📁 Creating certificate directory: ${CERT_DIR}"
    mkdir -p "${CERT_DIR}"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create directory ${CERT_DIR}"
        exec /docker-entrypoint.sh "$@"
    fi

    # Generate self-signed certificate valid for 365 days
    echo "🔑 Generating self-signed certificate..."
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "${KEY_FILE}" \
        -out "${CERT_FILE}" \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN}"

    if [ $? -eq 0 ]; then
        echo "✅ Certificate generated successfully"

        # Create chain file (copy of cert for self-signed)
        echo "📋 Creating chain file..."
        cp "${CERT_FILE}" "${CHAIN_FILE}"

        if [ $? -eq 0 ]; then
            echo "✅ Chain file created"
            echo "✅ Temporary self-signed certificate setup complete"
            echo ""
            echo "📌 Remember to generate real Let's Encrypt certificate after nginx starts:"
            echo "   cd ~/tcra-webhook-tester && bash scripts/ssl-setup.sh --standalone"
        else
            echo "⚠️  Failed to create chain file (non-critical)"
        fi
    else
        echo "❌ Failed to generate self-signed certificate"
        echo "🚨 Nginx may fail to start due to missing SSL certificates"
    fi

    echo ""
fi

# Execute the original nginx entrypoint
echo "🚀 Starting nginx..."
exec /docker-entrypoint.sh "$@"
