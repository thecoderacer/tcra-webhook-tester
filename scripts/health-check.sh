#!/bin/bash

# ====================================
# Health Check Script for Webhook Tester
# ====================================

echo "🔍 Webhook Tester Health Check"
echo "======================================"
echo ""

# Check if containers are running
echo "📊 Container Status:"
docker-compose ps
echo ""

# Check webhook-tester health
echo "🏥 Webhook Tester Health:"
if docker-compose exec -T webhook-tester wget -q --spider http://localhost:8080/health; then
    echo "✅ Webhook tester is healthy"
else
    echo "❌ Webhook tester is unhealthy"
fi
echo ""

# Check Nginx
echo "🌐 Nginx Health:"
if docker-compose exec -T nginx nginx -t 2>/dev/null; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration has errors"
fi
echo ""

# Check SSL Certificate
echo "🔒 SSL Certificate:"
if docker-compose exec -T certbot certbot certificates 2>/dev/null | grep -q "whtest.365cloud.my.id"; then
    echo "✅ SSL certificate exists"
    docker-compose exec -T certbot certbot certificates 2>/dev/null | grep -A 5 "whtest.365cloud.my.id"
else
    echo "⚠️  SSL certificate not found"
    echo "   Run: bash scripts/ssl-setup.sh"
fi

echo ""
echo "======================================"
echo "✅ Health check complete"
echo "======================================"
