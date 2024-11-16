# HAProxy Docker avec renouvellement automatique du certificat wildcard Let's Encrypt

[English 🇺🇸](README.md)

Une configuration HAProxy Dockerisée avec renouvellement automatique des certificats wildcard Let's Encrypt en utilisant `acme.sh` et la validation sécurisée DNS-01 via l'API Cloudflare.

## Table des matières

- [Introduction](#introduction)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
  - [1. Mise à jour du système](#1-mise-à-jour-du-système)
  - [2. Installer Docker et Docker Compose](#2-installer-docker-et-docker-compose)
  - [3. Installer Inotify-tools](#3-installer-inotify-tools)
- [Configuration](#configuration)
  - [1. Cloner le dépôt](#1-cloner-le-dépôt)
  - [2. Éditer les variables d'environnement](#2-éditer-les-variables-denvironnement)
  - [3. Éditer la configuration de Docker Compose](#3-éditer-la-configuration-de-docker-compose)
  - [4. Éditer la configuration de HAProxy](#4-éditer-la-configuration-de-haproxy)
  - [5. Configuration du service systemd](#5-configuration-du-service-systemd)
- [Exécution des services](#exécution-des-services)
- [Émission et installation des certificats](#émission-et-installation-des-certificats)
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
- **Service systemd** : Surveille les changements de certificats et recharge HAProxy.

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

Inotify-tools est requis pour que le service systemd surveille les changements de certificats.

```bash
sudo apt install inotify-tools -y
```

## Configuration

### 1. Cloner le dépôt

Clonez ce dépôt sur votre serveur.

```bash
git clone https://github.com/oturcot/docker-haproxy-letsencrypt.git
cd docker-haproxy-letsencrypt
```

### 2. Éditer les variables d'environnement

Le fichier `.env` à la racine du projet stocke vos identifiants API Cloudflare en toute sécurité. Éditez ce fichier pour y inclure votre email Cloudflare et votre clé API réels.

```bash
vim .env
```

Remplacez les placeholders par votre email Cloudflare et votre clé API réels :

```dotenv
CF_EMAIL=your-email@example.com
CF_API_KEY=your-cloudflare-api-key
```

**Important :** Assurez-vous que `.env` est inclus dans `.gitignore` pour empêcher que des informations sensibles ne soient poussées sur GitHub.

### 3. Éditer la configuration de Docker Compose

Le fichier `docker-compose.yml` est inclus dans le dépôt. Éditez ce fichier pour ajuster les configurations si nécessaire.

```bash
vim docker-compose.yml
```

**Notes :**

- Remplacez `/absolute/path/to/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.
- Assurez-vous que les chemins dans la section `volumes` pointent vers les emplacements corrects sur votre serveur.

### 4. Éditer la configuration de HAProxy

Le fichier `haproxy.cfg` se trouve dans le répertoire `haproxy`. Éditez ce fichier pour correspondre à vos domaines réels et aux IP de vos serveurs backend.

```bash
vim haproxy/haproxy.cfg
```

**Notes :**

- Remplacez `example.com`, `service1.example.com`, `service2.example.com` et les adresses IP par vos domaines et IP réels.
- Ajustez les ACL et les backends selon vos besoins.

### 5. Configuration du service systemd

Les fichiers de service systemd `watch_certificates.sh` et `watch_certificates.service` sont inclus dans le dépôt.

#### a. Éditer le script `watch_certificates.sh`

Éditez le script `watch_certificates.sh` à la racine du projet pour refléter les chemins corrects.

```bash
vim watch_certificates.sh
```

Remplacez `/absolute/path/to/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.

Rendez le script exécutable :

```bash
chmod +x watch_certificates.sh
```

#### b. Installer le fichier de service systemd

Copiez le fichier `watch_certificates.service` dans le répertoire `/etc/systemd/system/`.

```bash
sudo cp watch_certificates.service /etc/systemd/system/
```

#### c. Recharger et activer le service

Rechargez systemd pour reconnaître le nouveau service, puis activez-le et démarrez-le.

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

## Émission et installation des certificats

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
- Comme vous avez un service systemd qui surveille les changements de certificats et recharge HAProxy, vous n'avez pas besoin de spécifier un `--reloadcmd`.

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

Votre service systemd devrait automatiquement recharger HAProxy lorsque les fichiers de certificats changent. Cependant, vous pouvez redémarrer manuellement HAProxy pour vous assurer qu'il utilise le nouveau certificat.

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

Forcez un renouvellement de certificat pour tester l'ensemble du processus, y compris le rechargement de HAProxy par le service systemd.

```bash
docker exec acme_sh acme.sh --renew -d example.com -d '*.example.com' --force --home /acme.sh
```

Surveillez les journaux du service systemd pour confirmer que HAProxy se recharge.

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

---

Si vous rencontrez des problèmes ou avez des questions, n'hésitez pas à ouvrir une issue ou à contacter le mainteneur.
