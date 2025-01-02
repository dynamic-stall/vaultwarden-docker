# Vaultwarden Deployment with Cloudflare Tunnel

This repository contains scripts and configurations for deploying a self-hosted Vaultwarden instance with Cloudflare Tunnel integration, Nginx reverse proxy, and Docker Compose.

## Prerequisites

- Linux server (RHEL/CentOS/Rocky Linux/Fedora)
- Docker and Docker Compose installed
- Cloudflare account with a registered domain
- Basic understanding of networking and Docker concepts

## Components

1. **Docker Compose Setup**: Deploys Vaultwarden and Cloudflare Tunnel containers
2. **Nginx Reverse Proxy**: Handles SSL termination and request forwarding
3. **Cloudflare Tunnel**: Provides secure access without exposing ports
4. **Admin Token Generation**: Securely creates admin dashboard access

## Setup Instructions

### 1. Initial Setup

1. Clone this repository:
```bash
git clone https://github.com/yourusername/vaultwarden-deploy
cd vaultwarden-deploy
```

2. Create `.env` file with required variables:
```bash
cp .env.example .env
```

Required environment variables:
- `ADMIN_TOKEN`: Generated by admin-token-create.sh
- `BW_DOMAIN`: Your domain (e.g., vault.example.com)
- `BW_PORT`: Local port for Vaultwarden (default: 8443)
- `BW_IP`: Container IP address
- `CF_TOKEN`: Cloudflare Tunnel token
- `CF_IP`: Cloudflare container IP address
- `DOCKER_NET`: Docker network name
- `SMTP_*`: Email configuration variables

### 2. Cloudflare Tunnel Setup

1. Log into Cloudflare Zero Trust dashboard
2. Navigate to Access → Tunnels
3. Create new tunnel:
   - Click "Create a tunnel"
   - Name your tunnel
   - Copy the token for `CF_TOKEN` in `.env`
4. Configure public hostname:
   - Type: HTTP
   - URL: http://localhost:${BW_PORT}
   - Domain: Your chosen subdomain (e.g., vault.example.com)

### 3. Docker Network Setup

Create the required Docker network:
```bash
docker network create --subnet=172.20.0.0/16 your_network_name
```

### 4. Deployment

Run the main deployment script:
```bash
chmod +x deploy.sh
./deploy.sh
```

This will:
1. Generate admin token
2. Configure Nginx
3. Set up SSL certificates
4. Launch Docker containers

## File Structure

```
.
├── README.md
├── .env.example
├── scripts/
│   ├── admin-token-create.sh
│   ├── nginx-config.sh
│   └── deploy.sh
├── config/
│   ├── nginx/
│   │   └── bitwarden.conf
│   └── docker/
│       └── bw-compose.yml
└── .gitignore
```

## Security Considerations

- Always use strong passwords
- Keep your system updated
- Regularly backup the `/opt/bitwarden` directory
- Monitor logs for suspicious activity
- Use 2FA where possible

## Maintenance

### Backup

Backup the `/opt/bitwarden` directory regularly:
```bash
tar -czf backup.tar.gz /opt/bitwarden
```

### Updates

To update Vaultwarden:
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

1. Check container logs:
```bash
docker logs k-room
docker logs tk-room
```

2. Verify Nginx configuration:
```bash
nginx -t
```

3. Check Cloudflare tunnel status:
```bash
docker logs tk-room
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

