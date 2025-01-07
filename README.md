# Vaultwarden Deployment with Cloudflare Tunnel

**BLUF**: This repository contains scripts and configurations for deploying a self-hosted Vaultwarden instance with Cloudflare Tunnel integration, Nginx reverse proxy, and Docker Compose.

[Vaultwarden](https://hub.docker.com/r/vaultwarden/server) is an alternative implementation of the **Bitwarden** server API, written in Rust, and compatible with [upstream Bitwarden clients⁠](https://bitwarden.com/download/).

Bitwarden/Vaultwarden is capable of both [password management](https://bitwarden.com/help/password-manager-overview/) (via web app, desktop app, browser extension, mobile app, or CLI) and [secrets management](https://bitwarden.com/help/secrets-manager-overview/) (via web app, CLI, or SDK).

If you have a registered domain, you can further customize your Bitwarden experience by modifying the server URLs (instructions provided further down).

**Nginx and SSL setup are optional but highly recommended for enhanced security.** While you can deploy this setup using only Cloudflare Tunnel encryption, Cloudflare will be able to see the source and destination of your Vaultwarden instance. By terminating the tunnel at Nginx, this deployment strategy leverages the point-to-point encryption of Cloudflare Tunnels, while also adding an extra layer of security by ensuring encrypted traffic is further protected through SSL termination at Nginx.

If you would like to register your SSL certificates with Cloudflare, see [instructions](#cloudflare-origin-ca-certificate) further below.

<br>

## Prerequisites

- Linux server (_pref._ RHEL/CentOS/Fedora/Rocky... scripts use `dnf` package manager)
- [Docker](https://docs.docker.com/engine/install/) installed
- [Cloudflare account](https://dash.cloudflare.com/sign-up)
- (Registered domain optional; Cloudflare can assign a subdomain from `cfargotunnel.com` as your endpoint)
- Basic understanding of networking and Docker concepts

<br>

## Components

1. **Docker Compose Setup**: Deploys Vaultwarden and Cloudflare Tunnel containers
2. **Nginx Reverse Proxy**: Handles SSL termination and request forwarding
3. **Cloudflare Tunnel**: Provides secure access without exposing ports
4. **Admin Token Generation**: Securely creates admin dashboard access

<br>

## Setup Instructions

### 1. Initial Setup

1. Clone this repository:
```bash
git clone https://github.com/dynamic-stall/vaultwarden-docker
cd vaultwarden-docker
```

2. Create `.env` from `example` file (_be sure to add your personalized variables_):
```bash
cp .env.example .env
```

Required environment variables:
- `ADMIN_TOKEN`: Generated by `admin-token-create.sh`
- `BW_DOMAIN`: Your domain (e.g., vault.example.com)
- `BW_PORT`: Local port for Vaultwarden (default: 8443)
- `BW_IP`: Container IP address
- `CF_TOKEN`: Cloudflare Tunnel token
- `CF_IP`: Cloudflare container IP address
- `DOCKER_NET`: Docker network name
- `SMTP_*`: Email configuration variables

3. (Optional) If enabling SSL creation, create `openssl.cnf` from `example` file (_be sure to add your personalized variables_):
```bash
cp config/openssl.cnf.example config/openssl.cnf
```

### 2. Cloudflare Tunnel Setup

1. Log into [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) dashboard
2. Navigate to **Access** → **Tunnels**
3. Create new tunnel:
   - Click _"Create a tunnel"_
   - Name your tunnel
   - Copy the token for `CF_TOKEN` in `.env`
4. Configure public hostname:
   - **Type**: HTTP
   - **URL**: http://localhost:8443
   - **Domain**: Your chosen subdomain (e.g., vault.example.com)

### 3. Deployment

Run the main deployment script:
```bash
./deploy-vault.sh
```

This will:
1. Generate admin token
2. Optionally, create SSL certificates
4. Optionally, configure Nginx
5. Configure custom Docker network (predefined to use _172.31.20.0/26_; you can modify this via `./scripts/docker-custom-net.sh`)
6. Launch Docker containers 

<br>

## Configuring Clients

### Installing Bitwarden CLI

Instructions for installing the Bitwarden CLI based on your OS/environment can be found [here](https://bitwarden.com/help/cli/).

### Installing the Secrets Manager SDK

Instructions for installing the Bitwarden Secrets Manager SDK based on your language of choice can be found [here](https://bitwarden.com/help/secrets-manager-sdk/).

### Configuring Server URLs

#### Using the Web Vault:

1. Log out of your vault if currently logged in

2. On the login page, click "Settings" in the top right

3. Enter your server URL (ex: ```https://vault.example.com```)

4. Click _"Save"_ and proceed with login

#### Using the Desktop App:

1. Open Bitwarden desktop app

2. Expand the _"Accessing"_ dropdown menu below your login email

![image](https://github.com/user-attachments/assets/05dac953-5f70-42ff-a83e-6fd63516d5d3)

4. Select _"Self-hosted"_ and enter your server URL (ex: ```https://vault.example.com```)

![image](https://github.com/user-attachments/assets/e1fdc52d-3eb4-4459-8629-8d010f399406)

6. Continue logging in with the email and password set during configuration (NOT your master password, which is used to access the admin login page at ```https://vault.example.com/admin```)

#### Using the CLI:

Run the provided configuration script:
```bash
./scripts/configure-bw-cli.sh
```

Or manually configure:
```bash
# Set server URL
bw config server https://vault.example.com

# Configure individual endpoints
bw config server \
  --api https://vault.example.com/api \
  --identity https://vault.example.com/identity \
  --web-vault https://vault.example.com \
  --icons https://vault.example.com/icons \
  --notifications https://vault.example.com/notifications
```

#### Using the Secrets Manager SDK (Python):
```python
import logging
import os
from datetime import datetime, timezone

from bitwarden_sdk import BitwardenClient, DeviceType, client_settings_from_dict

# Create the BitwardenClient, which is used to interact with the SDK
client = BitwardenClient(
    client_settings_from_dict(
        {
            "apiUrl": os.getenv("API_URL"),
            "deviceType": DeviceType.SDK,
            "identityUrl": os.getenv("IDENTITY_URL"),
            "userAgent": "Python"
        }
    )
)

# Add some logging & set the org id
logging.basicConfig(level=logging.DEBUG)
organization_id = os.getenv("ORGANIZATION_ID")

# Set the state file location
# Note: the path must exist, the file will be created & managed by the SDK
state_path = os.getenv("STATE_FILE")

# Attempt to authenticate with the Secrets Manager Access Token
client.auth().login_access_token(os.getenv("ACCESS_TOKEN"), state_path)
```

**NOTE**: It's best to avoid hard-coding secrets into your code—especially for a secrets manager. This leads us to a classic chicken-and-egg scenario. If you have experience with this, _vete con Dios_... Currently, I'm working on my personal workflow for this situation. My approach is to use an Ansible vault file to encrypt client settings (such as the access token, API URL, etc.) and rely on one of the following methods for decryption during automated workflows:

1. A temporarily decrypted vault password file

2. Logging into the Bitwarden CLI and programmatically pulling the vault password via a secure note (I know; a bit roundabout)

<br>

## Cloudflare Origin CA Certificate

If you would like to register your SSL certificate with Cloudflare and obtain an **Origin CA certificate**, you will first need to generate a certificate signing request (CSR). Use the command below (replace with your private key name, if you brought your own):
```bash
openssl req -new -key private.key -out request.csr -config config/nginx/openssl.cnf
```

After you have your CSR, use it to obtain the Origin CA certificate by following the [official documentation](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/). Once you have registered your SSL certificate with Cloudflare and configured your setup to use them, you can discard the self-signed certificate, `certificate.crt`, **IF** it is no longer being used in your deployment...

<br>

## File Structure

```
.
├── config/
│   ├── docker/
│   │   └── bw-compose.yml
│   └── nginx/
|       ├── bitwarden.conf.template
│       └── openssl.cnf.example
├── deploy-vault.sh
├── .env.example
├── .gitignore
├── README.md  # this file
└── scripts/
    ├── admin-token-create.sh
    ├── bw-cli-config.sh
    ├── cloudflare-cert-register.sh
    ├── nginx-config.sh
    └── ssl-certs-create.sh
```

<br>

## Security Considerations

- Always use strong passwords
- Keep your system updated
- Regularly backup the `/opt/bitwarden` directory
- Monitor logs for suspicious activity
- Use 2FA where possible

<br>

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

<br>

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

<br>

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

