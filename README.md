# Webhook Tester Deployment

Automated deployment setup for Webhook Tester with Docker, nginx reverse proxy, and Let's Encrypt SSL certificates.

## Features

- **Webhook Tester**: Latest version from tarampampam/webhook-tester
- **Nginx**: Reverse proxy with SSL/TLS termination
- **Certbot**: Automatic SSL certificate generation and renewal
- **CI/CD**: GitHub Actions for automated deployment
- **Health Checks**: Automated service monitoring
- **Backup & Rollback**: Automatic backup before deployment

## Quick Start

### Prerequisites

- VPS with Docker and Docker Compose installed
- Domain name pointing to your VPS (whtest.365cloud.my.id)
- GitHub repository with secrets configured

### 1. Clone and Setup

```bash
# Clone repository
git clone <your-repo-url> ~/tcra-webhook-tester
cd ~/tcra-webhook-tester

# Copy and configure environment
cp .env.example .env
nano .env  # Edit with your values
```

### 2. Configure Environment

Edit `.env` file:

```env
# Domain
WEBHOOK_TESTER_HOST=whtest.365cloud.my.id

# Email for Let's Encrypt
ACME_EMAIL=your-email@example.com
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### 4. Generate SSL Certificates

```bash
# Generate SSL certificates
bash scripts/ssl-setup.sh --standalone

# Or if nginx is already running:
bash scripts/ssl-setup.sh
```

### 5. Access Webhook Tester

Visit: https://whtest.365cloud.my.id

## GitHub Actions Setup

### Required Secrets

Configure these secrets in your GitHub repository settings:

- `SSH_PRIVATE_KEY`: SSH private key for VPS access
- `SSH_HOST`: VPS IP address or hostname
- `SSH_USER`: SSH username (e.g., root or ubuntu)
- `SSH_PORT`: SSH port (default: 22)

### Workflows

- **CI**: Validation and security scanning on all pushes
- **CD**: Automated deployment to production on main branch

### First-Time Deployment

The CD workflow automatically handles first-time deployments:

1. **Auto-Initialize Repository**: Creates `~/tcra-webhook-tester` directory and initializes git if needed
2. **Environment Setup**: Creates `.env` from `.env.example` if not exists
3. **Skip Backup**: Skips backup on first deployment (no existing state)
4. **Pull and Deploy**: Pulls code from GitHub and starts containers

**Important**: After first deployment, SSH to VPS and:
```bash
cd ~/tcra-webhook-tester
nano .env  # Update with actual production values (if needed)
bash scripts/ssl-setup.sh --standalone  # Generate SSL certificates
```

## Port Configuration

**⚠️ Important**: This setup binds nginx to ports 80 and 443.

### If Deploying Multiple Services on Same VPS

If you're also running `tcra-n8n` or other services on the same VPS, you have these options:

**Option A: Single Shared Nginx (Recommended)**
1. Use one nginx container for all services
2. Add all domain configs to single nginx
3. Most efficient resource usage

**Option B: Different Ports**
1. n8n nginx: ports 80/443
2. Webhook tester nginx: ports 8080/8443
3. Update firewall to allow both ports

**Option C: Separate VPS Instances**
1. Deploy each service on different VPS
2. Complete isolation
3. Higher cost

## Scripts

### SSL Setup

```bash
# Generate SSL certificates (standalone mode)
bash scripts/ssl-setup.sh --standalone

# Generate with nginx running (webroot mode)
bash scripts/ssl-setup.sh

# Debug mode
bash scripts/ssl-setup.sh --debug --standalone
```

### Health Check

```bash
# Check all services
bash scripts/health-check.sh
```

## Maintenance

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f webhook-tester
docker-compose logs -f nginx
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart webhook-tester
docker-compose restart nginx
```

### Update

```bash
# Pull latest image
docker-compose pull

# Restart with new image
docker-compose up -d
```

## Troubleshooting

### Nginx Won't Start

**Error**: `cannot load certificate`

**Solution**:
```bash
# Generate SSL certificates first
bash scripts/ssl-setup.sh --standalone

# Then restart nginx
docker-compose up -d nginx
```

### Webhook Tester Not Accessible

1. Check container status:
   ```bash
   docker-compose ps
   ```

2. Check nginx logs:
   ```bash
   docker-compose logs nginx
   ```

3. Verify SSL certificate:
   ```bash
   docker-compose exec certbot certbot certificates
   ```

4. Test HTTP/HTTPS:
   ```bash
   curl -I http://whtest.365cloud.my.id
   curl -I https://whtest.365cloud.my.id
   ```

## Security Notes

1. **Firewall**: Only allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
2. **SSH Keys**: Use SSH keys instead of passwords
3. **Updates**: Regularly update Docker images
4. **Backups**: Implement regular backup strategy

## Architecture

```
Internet
   |
   v
Nginx (80/443)
   |
   v
Webhook Tester (8080)
```

## Directory Structure

```
tcra-webhook-tester/
├── docker-compose.yml      # Service orchestration
├── .env                    # Environment configuration
├── nginx/                  # Nginx configuration
│   ├── nginx.conf
│   └── conf.d/
│       └── webhook-tester.conf
├── .github/workflows/      # CI/CD pipelines
│   ├── ci.yml
│   └── cd-production.yml
├── scripts/                # Utility scripts
│   ├── ssl-setup.sh
│   └── health-check.sh
└── backups/                # Automatic backups
```

## License

MIT License

## Support

For issues and questions:
- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Webhook Tester: https://github.com/tarampampam/webhook-tester
