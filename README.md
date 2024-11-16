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
  - [2. Edit Docker Compose Configuration](#2-edit-docker-compose-configuration)
  - [3. Edit HAProxy Configuration](#3-edit-haproxy-configuration)
  - [4. Systemd Service Setup](#4-systemd-service-setup)
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
- Your Cloudflare account email and either an **API Token** or **API Key** with permissions to edit DNS records.

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
git clone https://github.com/oturcot/docker-haproxy-letsencrypt.git
cd docker-haproxy-letsencrypt
```

### 2. Edit Docker Compose Configuration

The `docker-compose.yml` file is included in the repository. Edit this file to adjust configurations as needed.

```bash
vim docker-compose.yml
```

**Notes:**

- Replace `/absolute/path/to/docker-haproxy-letsencrypt/` with the actual absolute path to your project directory.
- Ensure that the paths in the `volumes` section point to the correct locations on your server.

### 3. Edit HAProxy Configuration

The `haproxy.cfg` file is located in the `haproxy` directory. Edit this file to match your actual domains and backend server IPs.

```bash
vim haproxy/haproxy.cfg
```

**Notes:**

- Replace `example.com`, `service1.example.com`, `service2.example.com`, and IP addresses with your actual domains and IPs.
- Adjust the ACLs and backends according to your needs.

### 4. Systemd Service Setup

The systemd service files `watch_certificates.sh` and `watch_certificates.service` are included in the repository.

#### a. Edit the `watch_certificates.sh` Script

Edit the `watch_certificates.sh` script in the project root to reflect the correct paths and domain name.

```bash
vim watch_certificates.sh
```

- Replace `/absolute/path/to/docker-haproxy-letsencrypt/` with the actual absolute path to your project directory.
- Replace `example.com` with your actual domain name.

**Example:**

```bash
#!/bin/bash

CERT_DIR="/absolute/path/to/docker-haproxy-letsencrypt/certs/yourdomain.com"
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

Make the script executable:

```bash
chmod +x watch_certificates.sh
```

#### b. Install the Systemd Service File

Copy the `watch_certificates.service` file to the `/etc/systemd/system/` directory.

```bash
sudo cp watch_certificates.service /etc/systemd/system/
```

#### c. Reload and Enable the Service

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

### 1. Issue a New Certificate

Run the following command to issue a new Let's Encrypt wildcard certificate using the DNS-01 challenge with Cloudflare.

```bash
docker exec \
  -e CF_Email=your-email@example.com \
  -e CF_Token=your-cloudflare-api-token \
  acme_sh acme.sh \
  --issue \
  --dns dns_cf \
  -d yourdomain.com -d '*.yourdomain.com' \
  --keylength 4096 \
  --home /acme.sh \
  --accountemail your-email@example.com
```

**Replace:**

- `your-email@example.com` with your actual Cloudflare account email.
- `your-cloudflare-api-token` with your actual Cloudflare API **Token**. It's recommended to use an API Token with limited permissions.
- `yourdomain.com` with your actual domain name.

**Explanation:**

- `docker exec`: Runs a command in a running container.
- `-e CF_Email=...` and `-e CF_Token=...`: Sets the Cloudflare API credentials as environment variables for the command.
- `acme_sh`: The name of the `acme.sh` container.
- `acme.sh --issue`: Tells `acme.sh` to issue a new certificate.
- `--dns dns_cf`: Uses Cloudflare DNS API for DNS-01 validation.
- `-d yourdomain.com -d '*.yourdomain.com'`: Specifies the domain and wildcard domain.
- `--keylength 4096`: Sets the key length to 4096 bits.
- `--home /acme.sh`: Sets the home directory for `acme.sh`.
- `--accountemail your-email@example.com`: Sets your account email with Let's Encrypt.

**Note:** Passing API credentials via command line can be insecure. Ensure your system is secure and clean up your shell history if necessary.

### 2. Install the Certificate

After the certificate is issued, install it using the following command:

```bash
docker exec acme_sh acme.sh \
  --install-cert -d yourdomain.com -d '*.yourdomain.com' \
    --key-file       /acme.sh/yourdomain.com/fullchain.cer.key \
    --fullchain-file /acme.sh/yourdomain.com/fullchain.cer \
    --home           /acme.sh
```

**Notes:**

- This command uses the `acme_sh` container to install the certificate.
- The certificate and key files are saved in the specified locations.
- Since you have a systemd service that monitors certificate changes and reloads HAProxy, you do not need to specify a `--reloadcmd`.

### 3. Ensure Correct File Naming

Make sure that the key file is named `fullchain.cer.key` in the certificate directory. HAProxy can automatically find the key if it is named correctly and located in the same directory as the certificate.

### 4. Update HAProxy Configuration

Ensure your `haproxy.cfg` points to the correct certificate file:

```haproxy
frontend LAN_Frontend
    bind *:443 ssl crt /etc/haproxy/certs/yourdomain.com/fullchain.cer ssl-min-ver TLSv1.3
    # ... rest of your configuration ...
```

Replace `yourdomain.com` with your actual domain name.

### 5. Restart HAProxy

Your systemd service should automatically reload HAProxy when the certificate files change. However, you can manually restart HAProxy to ensure it's using the new certificate.

```bash
docker restart haproxy
```

## Verification

### 1. Check Certificate Details

Use OpenSSL to verify that HAProxy is serving the new Let's Encrypt certificate.

```bash
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -issuer -dates
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

To test automatic renewal, you can simulate the renewal process. Since `acme.sh` stores your API credentials in the `account.conf` file within the `/acme.sh` directory, it can renew certificates without needing to re-enter credentials.

Run the following command:

```bash
docker exec acme_sh acme.sh \
  --renew -d yourdomain.com -d '*.yourdomain.com' \
  --force \
  --home /acme.sh
```

Monitor the systemd service logs to confirm HAProxy reloads.

```bash
sudo journalctl -u watch_certificates.service -f
```

You should see output indicating that HAProxy has been reloaded.

## Security Best Practices

- **Protect API Tokens:** Do not expose your Cloudflare API Token in configuration files or version control. Use the command line to input sensitive information when necessary.
- **Use Scoped API Tokens:** Create an API Token with limited permissions (e.g., DNS:Edit permissions for specific zones) instead of using your global API Key.
- **Set Proper File Permissions:** Restrict access to sensitive files like certificates and keys.
- **Regularly Update Containers:** Use Watchtower to keep your Docker containers up to date with the latest security patches.
- **Limit Exposure:** Only expose necessary ports and services to the internet. Use firewalls to restrict access where possible.

## License

This project is licensed under the [MIT License](LICENSE).

---

**Disclaimer:** Replace all example domain names (`yourdomain.com`, `service1.yourdomain.com`, etc.) and IP addresses (`192.168.1.10`, `192.168.2.20`, etc.) with your actual domains and server IPs. Ensure that sensitive information such as API keys and passwords are kept secure and not exposed in public repositories.

---

If you encounter any issues or have questions, feel free to open an issue or contact the maintainer.
