# HAProxy Docker avec Renouvellement Automatique du Certificat Wildcard Let's Encrypt

[English 🇺🇸](README.md)

Une configuration HAProxy Dockerisée avec renouvellement automatique des certificats wildcard Let's Encrypt en utilisant `acme.sh` et la validation sécurisée DNS-01 via l'API Cloudflare.

## Table des Matières

- [Introduction](#introduction)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
  - [1. Mise à jour du système](#1-mise-à-jour-du-système)
  - [2. Installer Docker et Docker Compose](#2-installer-docker-et-docker-compose)
  - [3. Installer Inotify-tools](#3-installer-inotify-tools)
- [Configuration](#configuration)
  - [1. Cloner le dépôt](#1-cloner-le-dépôt)
  - [2. Variables d'environnement](#2-variables-denvironnement)
  - [3. Configuration de Docker Compose](#3-configuration-de-docker-compose)
  - [4. Configuration de HAProxy](#4-configuration-de-haproxy)
  - [5. Configuration du service Systemd](#5-configuration-du-service-systemd)
- [Exécution des services](#exécution-des-services)
- [Émission et Installation des certificats](#émission-et-installation-des-certificats)
- [Vérification](#vérification)
- [Bonnes pratiques de sécurité](#bonnes-pratiques-de-sécurité)
- [Licence](#licence)

## Introduction

Ce projet configure HAProxy dans un conteneur Docker pour gérer le trafic HTTP et HTTPS avec renouvellement automatique des certificats wildcard Let's Encrypt. Il utilise `acme.sh` pour la gestion des certificats et la validation DNS-01 de Cloudflare pour une émission et un renouvellement sécurisés et automatisés des certificats.

**Ce projet a été réalisé et testé sur Ubuntu 24.04 LTS.**

## Fonctionnalités

- **HAProxy Dockerisé** : Simplifie le déploiement et la gestion.
- **Renouvellement automatique des certificats** : Utilise `acme.sh` pour les certificats wildcard Let's Encrypt.
- **Défi DNS-01** : Validation sécurisée via l'API Cloudflare.
- **Frontaux LAN et WAN séparés** : Écoute sur les ports 80, 443 et 10443.
  - **Frontend LAN** : Accessible sur les ports 80 et 443.
  - **Frontend WAN** : Accessible sur le port 10443.
  - Vous pouvez configurer votre DNS interne pour pointer directement vers le serveur HAProxy pour les services internes.
  - Dans votre pare-feu, redirigez le port 443 de l'IP WAN vers le port 10443 du serveur HAProxy pour exposer uniquement les services souhaités.
- **Intégration de Watchtower** : Met à jour automatiquement les conteneurs Docker.
- **Service Systemd** : Surveille les changements de certificats et recharge HAProxy.

## Prérequis

- Un serveur exécutant **Ubuntu 24.04 LTS** ou compatible.
- Accès root ou sudo au serveur.
- Un nom de domaine avec DNS géré par Cloudflare.

## Installation

### 1. Mise à jour du système

Commencez par mettre à jour les paquets de votre système pour vous assurer que toutes les dépendances sont à jour.

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Installer Docker et Docker Compose

Installez Docker en utilisant le script d'installation officiel. Docker Compose est inclus avec l'installation de Docker.

```bash
# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Note :** Docker Compose est maintenant inclus dans l'installation de Docker et est invoqué en utilisant `docker compose` au lieu de `docker-compose`.

### 3. Installer Inotify-tools

Inotify-tools est requis pour que le service Systemd surveille les changements de certificats.

```bash
sudo apt install inotify-tools -y
```

## Configuration

### 1. Cloner le dépôt

Clonez ce dépôt sur votre serveur.

```bash
git clone https://github.com/yourusername/docker-haproxy-letsencrypt.git
cd docker-haproxy-letsencrypt
```

### 2. Variables d'environnement

Créez un fichier `.env` pour stocker vos identifiants API Cloudflare en toute sécurité.

```bash
touch .env
```

Ajoutez les lignes suivantes au fichier `.env`, en remplaçant les placeholders par votre email Cloudflare et votre clé API réels :

```dotenv
CF_EMAIL=votre-email@example.com
CF_API_KEY=votre-clé-api-cloudflare
```

**Important :** Ajoutez `.env` à votre `.gitignore` pour empêcher que des informations sensibles ne soient poussées sur GitHub.

```bash
echo ".env" >> .gitignore
```

### 3. Configuration de Docker Compose

Utilisez la configuration `docker-compose.yml` suivante. Remplacez les valeurs d'exemple par vos détails de configuration réels.

```yaml
services:
  haproxy:
    image: haproxy:lts
    container_name: haproxy
    volumes:
      - /chemin/absolu/vers/docker-haproxy-letsencrypt/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      - /chemin/absolu/vers/docker-haproxy-letsencrypt/certs:/etc/haproxy/certs:ro
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
      - /chemin/absolu/vers/docker-haproxy-letsencrypt/certs:/acme.sh
    restart: unless-stopped
```

**Notes :**

- Remplacez `/chemin/absolu/vers/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.
- Il est recommandé d'omettre la clé `version` dans `docker-compose.yml` selon la dernière spécification de Compose.

### 4. Configuration de HAProxy

Créez le fichier `haproxy.cfg` dans le répertoire `haproxy` avec le contenu suivant. Remplacez les domaines d'exemple et les adresses IP par vos données réelles.

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

    # Rediriger HTTP vers HTTPS
    http-request redirect scheme https unless { ssl_fc }

    # Définir l'en-tête X-Forwarded-Proto
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http if !{ ssl_fc }

    # ACLs pour chaque hôte
    acl host_service1 hdr(host) -i service1.example.com
    acl host_service2 hdr(host) -i service2.example.com
    # Ajoutez plus d'ACL si nécessaire

    # Utiliser les backends basés sur les ACLs
    use_backend service1_backend if host_service1
    use_backend service2_backend if host_service2
    # Ajoutez plus de backends si nécessaire

    # Backend par défaut
    default_backend default_backend

frontend WAN_Frontend
    bind *:10443 ssl crt /etc/haproxy/certs/example.com/fullchain.cer ssl-min-ver TLSv1.3
    mode http
    log global
    option http-keep-alive
    option forwardfor

    # Définir l'en-tête X-Forwarded-Proto
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http if !{ ssl_fc }

    # ACLs pour WAN
    acl host_wan_service hdr(host) -i wan-service.example.com
    use_backend wan_service_backend if host_wan_service

    # Backend par défaut (optionnel)
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

**Notes :**

- Remplacez `example.com`, `service1.example.com`, `service2.example.com` et les adresses IP par vos domaines et IP réels.
- Le frontend WAN écoute sur le port `10443`. Vous pouvez configurer votre pare-feu pour rediriger le port externe `443` vers le port interne `10443` sur le serveur HAProxy. De cette façon, vous exposez uniquement les services WAN que vous souhaitez.
- Pour les services internes, vous pouvez configurer votre DNS interne pour pointer directement vers le serveur HAProxy.

### 5. Configuration du service Systemd

Créez un service Systemd pour surveiller les changements de certificats et recharger HAProxy en conséquence.

#### a. Créer le script `watch_certificates.sh`

Créez un script `watch_certificates.sh` à la racine du projet avec le contenu suivant :

```bash
#!/bin/bash

CERT_DIR="/chemin/absolu/vers/docker-haproxy-letsencrypt/certs/example.com"
HAPROXY_CONTAINER="haproxy"

# Vérifier que inotifywait et docker sont disponibles
INOTIFYWAIT_PATH="/usr/bin/inotifywait"
DOCKER_PATH="/usr/bin/docker"

if [ ! -x "$INOTIFYWAIT_PATH" ]; then
    echo "inotifywait introuvable à $INOTIFYWAIT_PATH"
    exit 1
fi

if [ ! -x "$DOCKER_PATH" ]; then
    echo "Docker introuvable à $DOCKER_PATH"
    exit 1
fi

$INOTIFYWAIT_PATH -m -e close_write,moved_to,create "$CERT_DIR" |
while read -r directory events filename; do
  if [[ "$filename" == "fullchain.cer" || "$filename" == "fullchain.cer.key" ]]; then
    echo "Certificat mis à jour, rechargement de HAProxy..."
    $DOCKER_PATH kill -s HUP $HAPROXY_CONTAINER
  fi
done
```

**Notes :**

- Remplacez `/chemin/absolu/vers/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.
- Assurez-vous que le script utilise des chemins absolus pour `inotifywait` et `docker`.
- Le script surveille les changements des fichiers `fullchain.cer` et `fullchain.cer.key`.

Rendez le script exécutable :

```bash
chmod +x watch_certificates.sh
```

#### b. Créer le fichier de service Systemd

Créez un fichier de service Systemd nommé `watch_certificates.service` dans `/etc/systemd/system/` avec le contenu suivant :

```ini
[Unit]
Description=Surveille les changements de certificats et recharge HAProxy
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/chemin/absolu/vers/docker-haproxy-letsencrypt/watch_certificates.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
```

**Note :** Remplacez `/chemin/absolu/vers/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.

#### c. Activer et démarrer le service

Rechargez Systemd pour reconnaître le nouveau service, puis activez-le et démarrez-le.

```bash
sudo systemctl daemon-reload
sudo systemctl enable watch_certificates.service
sudo systemctl start watch_certificates.service
```

#### d. Vérifier le statut du service

Vérifiez si le service fonctionne correctement.

```bash
sudo systemctl status watch_certificates.service
```

Vous devriez voir un statut actif (en cours d'exécution).

## Exécution des services

Accédez à votre répertoire de projet et démarrez les conteneurs Docker en utilisant Docker Compose.

```bash
docker compose up -d
```

Cette commande va démarrer les conteneurs HAProxy, Watchtower et `acme_sh` en mode détaché.

## Émission et Installation des certificats

### 1. Configurer `acme.sh` pour utiliser Let's Encrypt

Définissez Let's Encrypt comme Autorité de Certification (CA) par défaut.

```bash
docker exec acme_sh acme.sh --set-default-ca --server letsencrypt --home /acme.sh
```

### 2. Émettre un nouveau certificat

Exécutez la commande suivante pour émettre un nouveau certificat wildcard Let's Encrypt en utilisant le défi DNS-01 avec Cloudflare.

```bash
docker exec acme_sh acme.sh --issue --dns dns_cf -d example.com -d '*.example.com' --keylength 4096 --home /acme.sh
```

**Explication :**

- `--dns dns_cf` : Utilise l'API DNS de Cloudflare pour la validation DNS-01.
- `-d example.com -d '*.example.com'` : Spécifie le domaine et le domaine wildcard.
- `--keylength 4096` : Définit la longueur de la clé à 4096 bits.

### 3. Installer le certificat

Installez le certificat émis et spécifiez les chemins pour les fichiers de clé et de chaîne complète.

```bash
docker exec acme_sh acme.sh --install-cert -d example.com -d '*.example.com' \
  --key-file       /acme.sh/example.com/fullchain.cer.key \
  --fullchain-file /acme.sh/example.com/fullchain.cer \
  --home           /acme.sh
```

**Notes :**

- `acme.sh` enregistre la clé sous le nom `fullchain.cer.key` lorsqu'elle est spécifiée.
- Comme vous avez un service Systemd qui surveille les changements de certificats et recharge HAProxy, vous n'avez pas besoin de spécifier un `--reloadcmd`.

### 4. Assurer le bon nommage des fichiers

Assurez-vous que le fichier de clé est nommé `fullchain.cer.key` dans le répertoire des certificats. HAProxy peut automatiquement trouver la clé si elle est nommée correctement et située dans le même répertoire que le certificat.

### 5. Mettre à jour la configuration de HAProxy

Assurez-vous que votre `haproxy.cfg` pointe vers le bon fichier de certificat :

```haproxy
frontend LAN_Frontend
    bind *:443 ssl crt /etc/haproxy/certs/example.com/fullchain.cer ssl-min-ver TLSv1.3
    # ... reste de votre configuration ...
```

**Notes :**

- HAProxy trouvera automatiquement le fichier de clé correspondant s'il est nommé `fullchain.cer.key` et situé dans le même répertoire.

### 6. Redémarrer HAProxy

Votre service Systemd devrait automatiquement recharger HAProxy lorsque les fichiers de certificats changent. Cependant, vous pouvez redémarrer manuellement HAProxy pour vous assurer qu'il utilise le nouveau certificat.

```bash
docker restart haproxy
```

## Vérification

### 1. Vérifier les détails du certificat

Utilisez OpenSSL pour vérifier que HAProxy sert le nouveau certificat Let's Encrypt.

```bash
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -issuer -dates
```

**Sortie attendue :**

```
issuer=CN=R3,O=Let's Encrypt,C=US
notBefore=16 Nov 2024 07:00:00 GMT
notAfter=14 Feb 2025 07:00:00 GMT
```

### 2. Surveiller les journaux

Assurez-vous que HAProxy a été rechargé avec succès en vérifiant ses journaux.

```bash
docker logs haproxy
```

Recherchez des entrées indiquant un rechargement réussi.

### 3. Tester le renouvellement automatique

Forcez un renouvellement de certificat pour tester l'ensemble du processus, y compris le rechargement de HAProxy par le service Systemd.

```bash
docker exec acme_sh acme.sh --renew -d example.com -d '*.example.com' --force --home /acme.sh
```

Surveillez les journaux du service Systemd pour confirmer que HAProxy se recharge.

```bash
sudo journalctl -u watch_certificates.service -f
```

Vous devriez voir une sortie indiquant que HAProxy a été rechargé.

## Bonnes pratiques de sécurité

- **Protégez les clés API :** Ne pas exposer votre clé API Cloudflare dans les fichiers de configuration. Utilisez des variables d'environnement ou des secrets Docker.
- **Utilisez des jetons API à portée limitée :** Au lieu d'utiliser votre clé API Cloudflare globale, créez un jeton API avec des permissions limitées (par exemple, permissions du défi DNS-01).
- **Sécurisez les fichiers `.env` :** Assurez-vous que vos fichiers `.env` ne sont pas suivis par le contrôle de version en les ajoutant à `.gitignore`.
- **Définissez les bonnes permissions de fichier :** Restreignez l'accès aux fichiers sensibles comme les certificats et les clés.
- **Mettez régulièrement à jour les conteneurs :** Utilisez Watchtower pour maintenir vos conteneurs Docker à jour avec les derniers correctifs de sécurité.
- **Limitez l'exposition :** N'exposez que les ports et services nécessaires à Internet. Utilisez des pare-feux pour restreindre l'accès lorsque c'est possible.

## Licence

Ce projet est sous licence [MIT License](LICENSE).

---

**Avertissement :** Remplacez tous les noms de domaine d'exemple (`example.com`, `service1.example.com`, etc.) et les adresses IP (`192.168.1.10`, `192.168.2.20`, etc.) par vos domaines et IP réels. Assurez-vous que les informations sensibles telles que les clés API et les mots de passe sont gardées sécurisées et ne sont pas exposées dans des dépôts publics.
