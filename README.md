# Docker HAProxy with Automatic Let's Encrypt Wildcard Certificate Renewal

[Français 🇫🇷](README.fr.md)

A Dockerized HAProxy setup with automatic Let's Encrypt wildcard certificate renewal using `acme.sh` and secure DNS-01 validation via Cloudflare API.

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [1. System Update and Upgrade](#1-system-update-and-upgrade)
  - [2. Install Docker and Docker Compose](#2-install-docker-and-docker-compose)
  - [3. Install Inotify-tools](#3-install-inotify-tools)
- [Configuration](#configuration)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Environment Variables](#2-environment-variables)
  - [3. Docker Compose Setup](#3-docker-compose-setup)
  - [4. HAProxy Configuration](#4-haproxy-configuration)
  - [5. Systemd Service Setup](#5-systemd-service-setup)
- [Running the Services](#running-the-services)
- [Issuing and Installing Certificates](#issuing-and-installing-certificates)
- [Verification](#verification)
- [Security Best Practices](#security-best-practices)
- [License](#license)

## Introduction

This project sets up HAProxy in a Docker container to manage HTTP and HTTPS traffic with automatic Let's Encrypt wildcard certificate renewal. It leverages `acme.sh` for certificate management and uses Cloudflare's DNS-01 challenge for secure and automated certificate issuance and renewal.

**This project was made and tested on Ubuntu 24.04 LTS.**

## Features

- **Dockerized HAProxy**: Simplifies deployment and management.
- **Automatic Certificate Renewal**: Uses `acme.sh` for Let's Encrypt wildcard certificates.
- **DNS-01 Challenge**: Secure validation via Cloudflare API.
- **Separate LAN and WAN Frontends**: Listens on ports 80, 443, and 10443.
  - **LAN Frontend**: Accessible on ports 80 and 443.
  - **WAN Frontend**: Accessible on port 10443.
  - You can set your internal DNS to point directly at the HAProxy server for internal services.
  - In your firewall, port forward the WAN IP on port 443 to the HAProxy server on port 10443 to expose only the desired services.
- **Watchtower Integration**: Automatically updates Docker containers.
- **Systemd Service**: Monitors certificate changes and reloads HAProxy.

## Prerequisites

- A server running **Ubuntu 24.04 LTS** or compatible.
- Root or sudo access to the server.
- A domain name with DNS managed by Cloudflare.

## Installation

### 1. System Update and Upgrade

Start by updating your system packages to ensure all dependencies are up to date.

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Docker and Docker Compose

Install Docker using the official installation script. Docker Compose is included with the Docker installation.

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Note:** Docker Compose is now included as part of the Docker installation and is invoked using `docker compose` instead of `docker-compose`.

### 3. Install Inotify-tools

Inotify-tools are required for the systemd service to monitor certificate changes.

```bash
sudo apt install inotify-tools -y
```

## Configuration

### 1. Clone the Repository

Clone this repository to your server.

```bash
git clone https://github.com/yourusername/docker-haproxy-letsencrypt.git
cd docker-haproxy-letsencrypt
```

### 2. Environment Variables

Create an `.env` file to store your Cloudflare API credentials securely.

```bash
touch .env
```

Add the following lines to the `.env` file, replacing the placeholders with your actual Cloudflare email and API key:

```dotenv
CF_EMAIL=your-email@example.com
CF_API_KEY=your-cloudflare-api-key
```

**Important:** Add `.env` to your `.gitignore` to prevent sensitive information from being pushed to GitHub.

```bash
echo ".env" >> .gitignore
```

### 3. Docker Compose Setup

Use the following `docker-compose.yml` configuration. Replace example values with your actual configuration details.

```yaml
services:
  haproxy:
    image: haproxy:lts
    container_name: haproxy
    volumes:
      - /absolute/path/to/docker-haproxy-letsencrypt/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      - /absolute/path/to/docker-haproxy-letsencrypt/certs:/etc/haproxy/certs:ro
    ports:
      - "80:80"
      - "443:443"
      - "10443:10443"
    restart: unless-stopped
    command: haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    environment:
      WATCHTOWER_SCHEDULE: "0 0 4 * * *"
      TZ: America/Toronto
      WATCHTOWER_CLEANUP: "true"
      WATCHTOWER_INCLUDE_RESTARTING: "true"
      WATCHTOWER_DEBUG: "true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  acme_sh:
    image: neilpang/acme.sh
    container_name: acme_sh
    command: daemon
    environment:
      - CF_EMAIL=${CF_EMAIL}
      - CF_API_KEY=${CF_API_KEY}
    volumes:
      - /absolute/path/to/docker-haproxy-letsencrypt/certs:/acme.sh
    restart: unless-stopped
```

**Notes:**

- Replace `/absolute/path/to/docker-haproxy-letsencrypt/` with the actual absolute path to your project directory.
- It's recommended to omit the `version` key in `docker-compose.yml` as per the latest Compose specification.

### 4. HAProxy Configuration

Create the `haproxy.cfg` file in the `haproxy` directory with the following content. Replace example domains and IP addresses with your actual data.

```haproxy
global
    log stdout format raw local0
    maxconn 4096
    nbthread 1
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  http-keep-alive
    option  forwardfor
    retries 3
    timeout connect 5000
    timeout client 50000
    timeout server 50000

frontend LAN_Frontend
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/example.com/fullchain.cer ssl-min-ver TLSv1.3
    mode http
    log global
    option http-keep-alive
    option forwardfor

    # Redirect HTTP to HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Set X-Forwarded-Proto header
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http if !{ ssl_fc }

    # ACLs for each host
    acl host_service1 hdr(host) -i service1.example.com
    acl host_service2 hdr(host) -i service2.example.com
    # Add more ACLs as needed

    # Use backends based on ACLs
    use_backend service1_backend if host_service1
    use_backend service2_backend if host_service2
    # Add more backends as needed

    # Default backend
    default_backend default_backend

frontend WAN_Frontend
    bind *:10443 ssl crt /etc/haproxy/certs/example.com/fullchain.cer ssl-min-ver TLSv1.3
    mode http
    log global
    option http-keep-alive
    option forwardfor

    # Set X-Forwarded-Proto header
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http if !{ ssl_fc }

    # ACLs for WAN
    acl host_wan_service hdr(host) -i wan-service.example.com
    use_backend wan_service_backend if host_wan_service

    # Default backend (optional)
    default_backend default_backend

# Backends
backend service1_backend
    server service1 192.168.1.10:8080

backend service2_backend
    server service2 192.168.1.11:8080

backend wan_service_backend
    server wan_service 192.168.2.20:8443 ssl verify none

backend default_backend
    server default_server 192.168.1.100:80
```

**Notes:**

- Replace `example.com`, `service1.example.com`, `service2.example.com`, and IP addresses with your actual domains and IPs.
- The WAN frontend listens on port `10443`. You can set your firewall to forward external port `443` to internal port `10443` on the HAProxy server. This way, you expose only the WAN services you intend to.
- For internal services, you can configure your internal DNS to point directly at the HAProxy server.

### 5. Systemd Service Setup

Create a systemd service to monitor certificate changes and reload HAProxy accordingly.

#### a. Create the `watch_certificates.sh` Script

Create a `watch_certificates.sh` script in the project root with the following content:

```bash
#!/bin/bash

CERT_DIR="/absolute/path/to/docker-haproxy-letsencrypt/certs/example.com"
HAPROXY_CONTAINER="haproxy"

# Ensure inotifywait and docker are available
INOTIFYWAIT_PATH="/usr/bin/inotifywait"
DOCKER_PATH="/usr/bin/docker"

if [ ! -x "$INOTIFYWAIT_PATH" ]; then
    echo "inotifywait not found at $INOTIFYWAIT_PATH"
    exit 1
fi

if [ ! -x "$DOCKER_PATH" ]; then
    echo "Docker not found at $DOCKER_PATH"
    exit 1
fi

$INOTIFYWAIT_PATH -m -e close_write,moved_to,create "$CERT_DIR" |
while read -r directory events filename; do
  if [[ "$filename" == "fullchain.cer" || "$filename" == "fullchain.cer.key" ]]; then
    echo "Certificate updated, reloading HAProxy..."
    $DOCKER_PATH kill -s HUP $HAPROXY_CONTAINER
  fi
done
```

**Notes:**

- Replace `/absolute/path/to/docker-haproxy-letsencrypt/` with the actual absolute path to your project directory.
- Ensure the script uses absolute paths for `inotifywait` and `docker`.
- The script monitors changes to `fullchain.cer` and `fullchain.cer.key` files.

Make the script executable:

```bash
chmod +x watch_certificates.sh
```

#### b. Create the Systemd Service File

Create a systemd service file named `watch_certificates.service` in `/etc/systemd/system/` with the following content:

```ini
[Unit]
Description=Watch for certificate changes and reload HAProxy
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/absolute/path/to/docker-haproxy-letsencrypt/watch_certificates.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
```

**Note:** Replace `/absolute/path/to/docker-haproxy-letsencrypt/` with the actual absolute path to your project directory.

#### c. Enable and Start the Service

Reload systemd to recognize the new service, then enable and start it.

```bash
sudo systemctl daemon-reload
sudo systemctl enable watch_certificates.service
sudo systemctl start watch_certificates.service
```

#### d. Verify the Service Status

Check if the service is running correctly.

```bash
sudo systemctl status watch_certificates.service
```

You should see an active (running) status.

## Running the Services

Navigate to your project directory and start the Docker containers using Docker Compose.

```bash
docker compose up -d
```

This command will start the HAProxy, Watchtower, and `acme_sh` containers in detached mode.

## Issuing and Installing Certificates

### 1. Configure `acme.sh` to Use Let's Encrypt

Set Let's Encrypt as the default Certificate Authority (CA).

```bash
docker exec acme_sh acme.sh --set-default-ca --server letsencrypt --home /acme.sh
```

### 2. Issue a New Certificate

Run the following command to issue a new Let's Encrypt wildcard certificate using the DNS-01 challenge with Cloudflare.

```bash
docker exec acme_sh acme.sh --issue --dns dns_cf -d example.com -d '*.example.com' --keylength 4096 --home /acme.sh
```

**Explanation:**

- `--dns dns_cf`: Uses Cloudflare DNS API for DNS-01 validation.
- `-d example.com -d '*.example.com'`: Specifies the domain and wildcard domain.
- `--keylength 4096`: Sets the key length to 4096 bits.

### 3. Install the Certificate

Install the issued certificate and specify the paths for the key and full chain files.

```bash
docker exec acme_sh acme.sh --install-cert -d example.com -d '*.example.com' \
  --key-file       /acme.sh/example.com/fullchain.cer.key \
  --fullchain-file /acme.sh/example.com/fullchain.cer \
  --home           /acme.sh
```

**Notes:**

- `acme.sh` saves the key as `fullchain.cer.key` when specified.
- Since you have a systemd service that monitors certificate changes and reloads HAProxy, you do not need to specify a `--reloadcmd`.

### 4. Ensure Correct File Naming

Make sure that the key file is named `fullchain.cer.key` in the certificate directory. HAProxy can automatically find the key if it is named correctly and located in the same directory as the certificate.

### 5. Update HAProxy Configuration

Ensure your `haproxy.cfg` points to the correct certificate file:

```haproxy
frontend LAN_Frontend
    bind *:443 ssl crt /etc/haproxy/certs/example.com/fullchain.cer ssl-min-ver TLSv1.3
    # ... rest of your configuration ...
```

**Notes:**

- HAProxy will automatically find the corresponding key file if it is named `fullchain.cer.key` and located in the same directory.

### 6. Restart HAProxy

Your systemd service should automatically reload HAProxy when the certificate files change. However, you can manually restart HAProxy to ensure it's using the new certificate.

```bash
docker restart haproxy
```

## Verification

### 1. Check Certificate Details

Use OpenSSL to verify that HAProxy is serving the new Let's Encrypt certificate.

```bash
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -issuer -dates
```

**Expected Output:**

```
issuer=CN=R3,O=Let's Encrypt,C=US
notBefore=Nov 16 07:00:00 2024 GMT
notAfter=Feb 14 07:00:00 2025 GMT
```

### 2. Monitor Logs

Ensure that HAProxy has reloaded successfully by checking its logs.

```bash
docker logs haproxy
```

Look for entries indicating a successful reload.

### 3. Test Automatic Renewal

Force a certificate renewal to test the entire process, including the systemd service reloading HAProxy.

```bash
docker exec acme_sh acme.sh --renew -d example.com -d '*.example.com' --force --home /acme.sh
```

Monitor the systemd service logs to confirm HAProxy reloads.

```bash
sudo journalctl -u watch_certificates.service -f
```

You should see output indicating that HAProxy has been reloaded.

## Security Best Practices

- **Protect API Keys:** Do not expose your Cloudflare API key in configuration files. Use environment variables or Docker secrets.
- **Use Scoped API Tokens:** Instead of using your global Cloudflare API key, create an API token with limited permissions (e.g., DNS-01 challenge permissions).
- **Secure `.env` Files:** Ensure that your `.env` files are not tracked by version control by adding them to `.gitignore`.
- **Set Proper File Permissions:** Restrict access to sensitive files like certificates and keys.
- **Regularly Update Containers:** Use Watchtower to keep your Docker containers up to date with the latest security patches.
- **Limit Exposure:** Only expose necessary ports and services to the internet. Use firewalls to restrict access where possible.

## License

This project is licensed under the [MIT License](LICENSE).

---

**Disclaimer:** Replace all example domain names (`example.com`, `service1.example.com`, etc.) and IP addresses (`192.168.1.10`, `192.168.2.20`, etc.) with your actual domains and server IPs. Ensure that sensitive information such as API keys and passwords are kept secure and not exposed in public repositories.

---

If you encounter any issues or have questions, feel free to open an issue or contact the maintainer.
