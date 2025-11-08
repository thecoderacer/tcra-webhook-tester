#!/bin/bash

# ====================================
# SSL Certificate Setup Script for Webhook Tester
# ====================================
# Setup SSL certificates with Let's Encrypt
# Usage: bash scripts/ssl-setup.sh [--debug] [--standalone]

set -e

# Parse arguments
DEBUG=false
FORCE_STANDALONE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=true
            shift
            ;;
        --standalone)
            FORCE_STANDALONE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash scripts/ssl-setup.sh [--debug] [--standalone]"
            exit 1
            ;;
    esac
done

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🔒 SSL Certificate Setup for Webhook Tester"
echo "======================================"
echo ""

# Get email from .env or prompt
if [ -z "$ACME_EMAIL" ] || [ "$ACME_EMAIL" = "your-email@example.com" ]; then
    echo "⚠️  ACME_EMAIL not set in .env file"
    read -p "Enter your email for Let's Encrypt: " ACME_EMAIL
fi

echo "📧 Using email: $ACME_EMAIL"
echo ""

# ====================================
# Prerequisite Checks
# ====================================

echo "🔍 Running prerequisite checks..."
echo ""

# Check 1: Docker-Compose running
echo "1️⃣ Checking if containers are running..."
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ No containers are running!"
    echo "   Please start services first: docker-compose up -d"
    exit 1
fi
echo "✅ Containers are running"
echo ""

# Check 2: Nginx is running (skip if standalone mode)
if [ "$FORCE_STANDALONE" != true ]; then
    echo "2️⃣ Checking nginx status..."
    if ! docker-compose ps nginx | grep -q "Up"; then
        echo "❌ Nginx is not running!"
        echo "   Please start nginx: docker-compose up -d nginx"
        echo "   Or use standalone mode: bash scripts/ssl-setup.sh --standalone"
        exit 1
    fi
    echo "✅ Nginx is running"
else
    echo "2️⃣ Standalone mode - skipping nginx check"
    echo "✅ Nginx check skipped (will use standalone method)"
fi
echo ""

# Check 3: DNS resolution
echo "3️⃣ Checking DNS resolution..."
echo "   Checking whtest.365cloud.my.id..."
if ! nslookup whtest.365cloud.my.id >/dev/null 2>&1 && ! host whtest.365cloud.my.id >/dev/null 2>&1; then
    echo "⚠️  Warning: DNS resolution failed for whtest.365cloud.my.id"
    echo "   Make sure DNS A record points to this server"
    read -p "   Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        exit 1
    fi
else
    echo "✅ DNS resolves for whtest.365cloud.my.id"
fi
echo ""

echo "======================================"
echo "✅ Prerequisites check completed!"
echo "======================================"
echo ""

# ====================================
# SSL Certificate Generation
# ====================================

# Function to generate certificate with webroot method
generate_cert_webroot() {
    local domain=$1
    local email=$2

    echo "📜 Generating certificate for $domain using webroot method..."

    if [ "$DEBUG" = true ]; then
        docker-compose run --rm certbot certonly \
          --webroot \
          --webroot-path=/var/www/acme-challenge \
          --email "$email" \
          --agree-tos \
          --no-eff-email \
          --non-interactive \
          -d "$domain" \
          --verbose
    else
        timeout 120 docker-compose run --rm certbot certonly \
          --webroot \
          --webroot-path=/var/www/acme-challenge \
          --email "$email" \
          --agree-tos \
          --no-eff-email \
          --non-interactive \
          -d "$domain" 2>&1 || return 1
    fi

    return 0
}

# Function to generate certificate with standalone method
generate_cert_standalone() {
    local domain=$1
    local email=$2

    echo "📜 Generating certificate for $domain using standalone method..."
    echo "⚠️  This will temporarily stop nginx..."

    # Stop nginx
    docker-compose stop nginx

    # Generate cert
    if [ "$DEBUG" = true ]; then
        docker-compose run --rm -p 80:80 certbot certonly \
          --standalone \
          --preferred-challenges http \
          --email "$email" \
          --agree-tos \
          --no-eff-email \
          --non-interactive \
          -d "$domain" \
          --verbose
    else
        docker-compose run --rm -p 80:80 certbot certonly \
          --standalone \
          --preferred-challenges http \
          --email "$email" \
          --agree-tos \
          --no-eff-email \
          --non-interactive \
          -d "$domain" 2>&1
    fi

    local result=$?

    # Start nginx again
    docker-compose start nginx
    sleep 5

    return $result
}

# Setup SSL for webhook-tester
echo "🔐 Setting up SSL for whtest.365cloud.my.id..."
echo ""

if [ "$FORCE_STANDALONE" = true ]; then
    # Force standalone mode
    if generate_cert_standalone "whtest.365cloud.my.id" "$ACME_EMAIL"; then
        echo "✅ Certificate obtained for whtest.365cloud.my.id"
    else
        echo "❌ Failed to obtain certificate for whtest.365cloud.my.id"
        exit 1
    fi
else
    # Try webroot first, fallback to standalone
    if generate_cert_webroot "whtest.365cloud.my.id" "$ACME_EMAIL"; then
        echo "✅ Certificate obtained for whtest.365cloud.my.id (webroot)"
    else
        echo "⚠️  Webroot method failed, trying standalone method..."
        if generate_cert_standalone "whtest.365cloud.my.id" "$ACME_EMAIL"; then
            echo "✅ Certificate obtained for whtest.365cloud.my.id (standalone)"
        else
            echo "❌ Both methods failed for whtest.365cloud.my.id"
            echo ""
            echo "Troubleshooting:"
            echo "1. Check DNS: nslookup whtest.365cloud.my.id"
            echo "2. Check firewall: sudo ufw status"
            echo "3. Check nginx logs: docker-compose logs nginx"
            echo "4. Try debug mode: bash scripts/ssl-setup.sh --debug"
            exit 1
        fi
    fi
fi

echo ""

# Reload nginx
echo "🔄 Reloading nginx with new certificates..."
if docker-compose exec -T nginx nginx -s reload 2>/dev/null; then
    echo "✅ Nginx reloaded successfully"
else
    echo "⚠️  Nginx reload failed, restarting container..."
    docker-compose restart nginx
    sleep 5
    echo "✅ Nginx restarted"
fi

echo ""
echo "======================================"
echo "✅ SSL Setup Complete!"
echo "======================================"
echo ""
echo "🌐 Your webhook tester is now accessible via HTTPS:"
echo "   - https://whtest.365cloud.my.id"
echo ""
echo "📝 Certificate will auto-renew every 12 hours"
echo ""
echo "🔍 Verify certificate:"
echo "   curl -I https://whtest.365cloud.my.id"
echo "======================================"
