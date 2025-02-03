# Vaultwarden Deployment with Cloudflare Tunnel

**BLUF**: This repository contains scripts and configurations for deploying a self-hosted Vaultwarden instance with Cloudflare Tunnel integration and (optional) DuckDNS custom subdomain via Docker Compose.

[Vaultwarden](https://hub.docker.com/r/vaultwarden/server) is an alternative implementation of the **Bitwarden** server API, written in Rust, and compatible with [upstream Bitwarden clients⁠](https://bitwarden.com/download/).

Bitwarden/Vaultwarden is capable of [password management](https://bitwarden.com/help/password-manager-overview/) via web app, desktop app, browser extension, mobile app, or CLI.

[DuckDNS](https://hub.docker.com/r/linuxserver/duckdns) is a free dynamic DNS service. It allows users to create custom domain names that automatically update to point to a specific IP address, which is particularly useful for home servers, remote access, or hosting services with changing IP addresses. Users can choose a subdomain under duckdns.org and configure it to always point to their current IP address, making it easier to access their network or servers remotely.

If you have a registered domain, you can further customize your Bitwarden experience by modifying the server URLs (instructions provided further down).

<br>

## Prerequisites

- Linux/macOS server (or WSL instance if running Windows)
- [Docker](https://docs.docker.com/engine/install/) installed
- [Cloudflare account](https://dash.cloudflare.com/sign-up)
- [DuckDNS account](https://www.duckdns.org/) + registered subdomain and token \<OR\> personal registered domain
- Basic understanding of networking and Docker concepts

<br>

## Components

1. **Docker Compose Setup:** Deploys Vaultwarden and Cloudflare Tunnel containers
2. **(Optional) DuckDNS subdomain:** Allows for secure access to your vault instance without relying on an IP address
3. **Cloudflare Tunnel:** Provides secure access without exposing ports
4. **Cloudflare Domain:** Add you own registered domain or DuckDNS subdomain to your Cloudflare dashboard to resolve traffic to your Vaultwarden instance behind the Cloudflare Tunnel
5. **(Optional) Nginx Configuration:** Nginx reverse proxy for SSL termination (useful if deploying as part of a larger infrastructure, i.e., you already have other containers deployed as part of your infrastructure)
6. **Admin Token Generation:** Securely creates admin dashboard access

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
- `VAULT_NAME`: Vaultwarden container and hostname (used to create `DOMAIN_URL`)
- `VAULT_VOLUME`: Persistent volume for vaultwarden container and automated back-up locations
- `VAULT_PORT`: Local port for Vaultwarden (default: 8443)
- `TUNNEL_TOKEN`: Cloudflare Tunnel token (obtained from your personal Cloudflare account)
- `SMTP_*`: Email configuration variables (default: smtp.gmail.com)
- `DDNS_DOMAIN`: (_Optional_) Your DuckDNS subdomain (i.e., `example.ddns.com`; used to create `DOMAIN_URL`)
- `DDNS_TOKEN`: (_Optional_) DuckDNS subdomain token (obtained from your personal DuckDNS account)
- `DOMAIN_NAME`: Either your DuckDNS subdomain or your personal registered domain name (used to create `DOMAIN_URL`)
- `ADMIN_TOKEN`: Generated by `admin-token-create.sh`

_(**NOTE:** More on `DOMAIN_NAME` variable setup further down)_

3. (_Optional_) If deploying with Nginx, you will need to either have your own SSL certificates (i.e., `private.key` and `certificate.crt`) or the `deploy-nginx.sh` script will generate them for you.

Copy the `config/nginx/openssl.cnf.example` file and update with your own values:
```bash
cd config/nginx
cp openssl.cnf.example openssl.cnf
```

**NOTE:** Before running the `deploy-nginx.sh` script, be sure to have the absolute paths to your SSL certificates.

- The following will be auto-configured for you:
  - SSL private key and self-signed certificate
  - `vaultwarden.conf` Nginx configuration file
  - Nginx server configuration

_(**NOTE II:** If skipping Nginx and SSL configuration, simply run the `deploy-standalone.sh` script.)_

<br>

### 2. Domain Name Configuration

#### Option 1: Using DuckDNS (Free Domain)

1. Visit [DuckDNS](https://www.duckdns.org/) and sign in using your preferred OAuth provider

![image](https://github.com/user-attachments/assets/581f6db4-0e73-45e5-9e38-91747637223c)

2. Create a subdomain (i.e., _vault.duckdns.org_)

3. Copy your token from the DuckDNS dashboard

![image](https://github.com/user-attachments/assets/3953e37b-be5f-49cd-9ce0-ca62063bcef7)

4. Modify these variables to your `.env` file:
```bash
DDNS_DOMAIN=<your-chosen-subdomain>
DDNS_TOKEN=<your-duckdns-token>
```
* **NOTE** If you own `example.duckdns.org`, then set `DDNS_DOMAIN=example`.

The DuckDNS container will automatically:
- Update your IP address every 5 minutes
- Maintain your subdomain registration
- Handle logging and retry logic
- Keep your subdomain active (domains remain valid as long as they're updated once every 30 days)

* No additional maintenance is required as long as the container remains running.

#### Option 2: Using Your Own Domain

If you have a registered domain, you can skip the DuckDNS setup and modify the `vw-compose.yml` file:

1. Remove the DuckDNS service block:
```yaml
  # Remove this entire block
  duckdns:
    image: linuxserver/duckdns
    # ...
```

2. Update the `DOMAIN_NAME` variable in `.env`, either commenting out or deleting the first `DOMAIN_NAME` variable referencing the DuckDNS subdomain:

Get rid of:
```bash
DOMAIN_NAME="${DDNS_DOMAIN}.duckdns.org"
```

...and modify the following variable:
```bash
# Remove the "#" and enter your personal registered domain
DOMAIN_NAME="example.com"
```

**NOTE:** Regardless of whether you use DuckDNS or bring your own domain, the final `DOMAIN_URL` variable will be correctly formatted for use in later configurations:
```bash
DOMAIN_URL="https://${VAULT_NAME}.${DOMAIN_NAME}"
```

<br>


### 3. Cloudflare Domain Zone Setup

⚠️ **Skip this step if using DuckDNS** ⚠️

1. Login to your [Cloudflare account](https://dash.cloudflare.com/)

2. Navigate to **Account Home** → **Domains**

3. Select the blue `+ Add a domain` button to enter your domain name: either your full DuckDNS subdomain or your personal registered domain. Leave default settings as they are.

![image](https://github.com/user-attachments/assets/c29ab84e-5bea-4147-8feb-6c7af702bcf8)

4. In your DNS dashboard, you should see four records: two _A records_ (containing your current public IP address) and two _MX records_ (ignore these...).

![image](https://github.com/user-attachments/assets/f62b8ece-ac8a-41f8-bfb2-353e498fb273)

5. Save this page for later; we'll come back to it for the next step...

<br>

### 4. Cloudflare Tunnel Setup

1. Login to your [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) dashboard

2. Navigate to **Networks** → **Tunnels**

3. Create a new tunnel:
   - Click _Create a tunnel_.
   - Select _Cloudflared_ on the left.
   - Name your tunnel (the name is only important to you). Click _Save_ on the bottom-right.
   - Under the "Choose your environment" options, select _Docker_.
   ![image](https://github.com/user-attachments/assets/28f33bd6-dfdf-48ea-bcf0-0393b9a49143)

   - Under "Install and run a connector", copy the `docker run` command provided. Paste this command in a secure note-taking environment to see the full **token**.
   - Copy this token and paste it into your `.env` file, updating the `TUNNEL_TOKEN` variable.
   ```bash
   # Cloudflare Configuration
   TUNNEL_NAME="${VAULT_NAME}-tunnel"   # NOTE: this variable is for the Docker container name
   TUNNEL_TOKEN="<your-cloudflare-tunnel-token>"
   ```
   - Back to your Cloudflare dashboard, click _Save_ on the bottom-right.

4. Configure the tunnel's _Public Hostname_:
   - **Subdomain:** Ensure this value matches your chosen `VAULT_NAME` value in your `.env` file
   - **Domain:** Either your personal registered domain name (i.e., `example.com`) or your DuckDNS subdomain (i.e., `example.duckdns.org`)
   - **Path:** _(Leave this field blank)_
   - **Type:** HTTP
   - **URL:** localhost:8443  (or your chosen `VAULT_PORT` value, if you changed it)
  
  * **NOTE:** If you are using a DuckDNS subdomain, you will not be able to add your subdomain to your Cloudflare dashboard for longer than 28 days (without _NS record_ verification, which isn't possible with DuckDNS). You can still enter a **"custom domain name"** in the _Public Hostname_ section. **Be sure to hit the _ENTER_ key when populating this value so it doesn't disappear**. A _warning_ for custom domains will appear. It means nothing configuration-wise, but be mindful:

  ![image](https://github.com/user-attachments/assets/36a60b6a-7276-4bb5-ae1b-e98d0d9b2b4f)

5. (Optional) Configure the tunnel's _Private Network_:
    - Cloudflare offers an extensive array of features available at free-tier. If you plan on utilizing WARP with your Zero Trust account (which I recommend), you can implement more robust [access policies](https://developers.cloudflare.com/cloudflare-one/policies/access/) as well as custom [private networks/IPs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/) to access remote resources without requiring a public domain
    - For the sake of simplicity, these instructions are beyond the scope of this GitHub project, but I suggest you check them out on your own, especially Cloudflare Access -- which can secure access to your self-hosted applications and more via various authentication and posture-assessment methods (i.e., Google OIDC for single sign-on with your Gmail account, restricting access to resources based on public IP or country, and much, much more).

6. Click _Save tunnel_ in the bottom-right.

<br>

### 5. Deployment

Run one of the main deployment scripts:

If configuring SSL and Nginx, run:
```bash
./deploy-nginx.sh
```

This will:
1. Generate admin token
2. Create SSL certificates
3. Configure Nginx
4. Launch Docker containers
5. (Optionally,) configure Bitwarden CLI

<br>

If deploying without nginx, run:
```bash
./deploy-standalone.sh
```

This will:
1. Generate admin token
2. Launch Docker containers
3. (Optionally,) configure Bitwarden CLI

<br>

## Accessing Your Vault

### Configuring Clients

#### Using the Web Vault:

1. Navigate to the admin panel of your Vaultwarden instance (i.e., `vault.example.com/admin`)

2. Use the Admin token you set to authenticate

3. From the admin page, you can create users for general access and password management (access the Web Vault at, i.e., `vault.example.com/#/login`)

#### Using the Desktop App:

1. Open Bitwarden desktop app

2. Expand the _"Accessing"_ dropdown menu below your login email

![image](https://github.com/user-attachments/assets/05dac953-5f70-42ff-a83e-6fd63516d5d3)

3. Select _"Self-hosted"_ and enter your server URL (ex: ```https://vault.example.com```)

![image](https://github.com/user-attachments/assets/e1fdc52d-3eb4-4459-8629-8d010f399406)

4. Use the initial admin credentials provided during setup

<br>

### Programmatic Access

#### Using the CLI:

The main deployment scripts will (optionally) build a _Docker container_ which will allow you to run the Bitwarden CLI -- while also pre-configuring it to use your custom domain.

**NOTE:** If you would prefer a _host installation_ of the CLI, you can use the `scripts/cli-host-config.sh` script instead of the Docker deployment.

Reference the below for manual configuration of the CLI:
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

<br>

## Cloudflare Origin CA Certificate

If you would like to register your SSL certificate with Cloudflare (or another certificate authority) and obtain an **Origin CA certificate**, you will first need to generate a certificate signing request (CSR). Use the command below (replace with your private key name, if you brought your own):
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
│   │   ├── cli.Dockerfile
|   |   └── vw-compose.yml
│   └── nginx/
|       ├── vaultwarden.conf.template
│       └── openssl.cnf.example
├── deploy-nginx.sh
├── deploy-standalone.sh
├── .env.example
├── .gitignore
├── README.md  # this file
└── scripts/
    ├── admin-token-create.sh
    ├── bw-cli-config.sh
    ├── cli-config-host.sh
    ├── docker-custom-net.sh
    ├── nginx-config.sh
    └── ssl-cert-create.sh
```

<br>

## Security Considerations

- Always use strong passwords
- Keep your system updated
- Regularly backup the `/opt/bitwarden` directory (automated by default)
- Monitor logs for suspicious activity
- Use 2FA where possible

<br>

## Maintenance

### Backup

Back-ups are AUTOMATED via the `vw_backup` container as part of the `vw-compose.yml` file. Default is set to daily at 5 AM.

For manual back-ups, you can back up the `/opt/vaultwarden` directory:
```bash
tar -czf backup.tar.gz /opt/vaultwarden
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
docker logs <vault_container_name>
docker logs <tunnel_container_name>
```

2. Verify Nginx configuration:
```bash
nginx -t
```

3. Check Cloudflare tunnel status:
```bash
docker logs <tunnel_container_name>
```

<br>

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

