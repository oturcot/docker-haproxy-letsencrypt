# Docker HAProxy avec renouvellement automatique de certificat wildcard Let's Encrypt

[English 🇬🇧](README.md)

Une configuration HAProxy Dockerisée avec renouvellement automatique de certificat wildcard Let's Encrypt utilisant `acme.sh` et une validation DNS-01 sécurisée via l'API Cloudflare.

## Table des matières

- [Introduction](#introduction)
- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation](#installation)
  - [1. Mise à jour du système](#1-mise-à-jour-et-amélioration-du-système)
  - [2. Installer Docker et Docker Compose](#2-installer-docker-et-docker-compose)
  - [3. Installer Inotify-tools](#3-installer-inotify-tools)
- [Configuration](#configuration)
  - [1. Cloner le dépôt](#1-cloner-le-dépôt)
  - [2. Modifier la configuration de Docker Compose](#2-modifier-la-configuration-docker-compose)
  - [3. Modifier la configuration de HAProxy](#3-modifier-la-configuration-haproxy)
  - [4. Configuration du service systemd](#4-configuration-du-service-systemd)
- [Exécution des services](#exécution-des-services)
- [Émission et installation des certificats](#émission-et-installation-des-certificats)
- [Vérification](#vérification)
- [Bonnes pratiques de sécurité](#meilleures-pratiques-de-sécurité)
- [Licence](#licence)

## Introduction

Ce projet configure HAProxy dans un conteneur Docker pour gérer le trafic HTTP et HTTPS avec renouvellement automatique de certificat wildcard Let's Encrypt. Il utilise `acme.sh` pour la gestion des certificats et le challenge DNS-01 de Cloudflare pour une émission et un renouvellement sécurisés et automatisés des certificats.

**Ce projet a été réalisé et testé sur Ubuntu 24.04 LTS.**

## Fonctionnalités

- **HAProxy Dockerisé** : Simplifie le déploiement et la gestion.
- **Renouvellement automatique des certificats** : Utilise `acme.sh` pour les certificats wildcard Let's Encrypt.
- **Challenge DNS-01** : Validation sécurisée via l'API Cloudflare.
- **Frontends LAN et WAN séparés** : Écoute sur les ports 80, 443 et 10443.
  - **Frontend LAN** : Accessible sur les ports 80 et 443.
  - **Frontend WAN** : Accessible sur le port 10443.
  - Vous pouvez configurer votre DNS interne pour pointer directement vers le serveur HAProxy pour les services internes.
  - Dans votre pare-feu, redirigez le port 443 de l'IP WAN vers le serveur HAProxy sur le port 10443 pour exposer uniquement les services souhaités.
- **Intégration Watchtower** : Met automatiquement à jour les conteneurs Docker.
- **service systemd** : Surveille les changements de certificats et recharge HAProxy.

## Prérequis

- Un serveur exécutant **Ubuntu 24.04 LTS** ou compatible.
- Accès root ou sudo au serveur.
- Un nom de domaine avec DNS géré par Cloudflare.
- L'adresse e-mail de votre compte Cloudflare et soit un **Token API** soit une **Clé API** avec les permissions pour modifier les enregistrements DNS.

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

**Note :** Docker Compose est désormais inclus dans l'installation de Docker et est invoqué en utilisant `docker compose` au lieu de `docker-compose`.

### 3. Installer Inotify-tools

Les outils Inotify sont nécessaires pour que le service systemd surveille les changements de certificats.

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

### 2. Modifier la configuration de Docker Compose

Le fichier `docker-compose.yml` est inclus dans le dépôt. Modifiez ce fichier pour ajuster les configurations selon vos besoins.

```bash
vim docker-compose.yml
```

**Notes :**

- Remplacez `/absolute/path/to/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.
- Assurez-vous que les chemins dans la section `volumes` pointent vers les emplacements corrects sur votre serveur.

### 3. Modifier la configuration de HAProxy

Le fichier `haproxy.cfg` est situé dans le répertoire `haproxy`. Modifiez ce fichier pour correspondre à vos domaines réels et aux adresses IP des serveurs backend.

```bash
vim haproxy/haproxy.cfg
```

**Notes :**

- Remplacez `example.com`, `service1.example.com`, `service2.example.com` et les adresses IP par vos domaines et IP réels.
- Ajustez les ACL et les backends selon vos besoins.

### 4. Configuration du service systemd

Les fichiers de service systemd `watch_certificates.sh` et `watch_certificates.service` sont inclus dans le dépôt.

#### a. Modifier le script `watch_certificates.sh`

Modifiez le script `watch_certificates.sh` à la racine du projet pour refléter les chemins corrects et le nom de domaine.

```bash
vim watch_certificates.sh
```

- Remplacez `/absolute/path/to/docker-haproxy-letsencrypt/` par le chemin absolu réel vers votre répertoire de projet.
- Remplacez `example.com` par votre nom de domaine réel.

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

Naviguez vers votre répertoire de projet et démarrez les conteneurs Docker en utilisant Docker Compose.

```bash
docker compose up -d
```

Cette commande démarrera les conteneurs HAProxy, Watchtower et `acme_sh` en mode détaché.

## Émission et installation des certificats

### 1. Configurer `acme.sh` pour utiliser Let's Encrypt
Définissez Let's Encrypt comme Autorité de Certification (CA) par défaut.
```bash
docker exec acme_sh acme.sh --set-default-ca --server letsencrypt --home /acme.sh
```

### 2. Émettre un nouveau certificat

Exécutez la commande suivante pour émettre un nouveau certificat wildcard Let's Encrypt en utilisant le challenge DNS-01 avec Cloudflare.

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

**Remplacez :**

- `your-email@example.com` par l'adresse e-mail réelle de votre compte Cloudflare.
- `your-cloudflare-api-token` par votre **Token API** Cloudflare réel. Il est recommandé d'utiliser un Token API avec des permissions limitées.
- `yourdomain.com` par votre nom de domaine réel.

**Explication :**

- `docker exec` : Exécute une commande dans un conteneur en cours d'exécution.
- `-e CF_Email=...` et `-e CF_Token=...` : Définit les identifiants API Cloudflare en tant que variables d'environnement pour la commande.
- `acme_sh` : Le nom du conteneur `acme.sh`.
- `acme.sh --issue` : Indique à `acme.sh` d'émettre un nouveau certificat.
- `--dns dns_cf` : Utilise l'API DNS de Cloudflare pour la validation DNS-01.
- `-d yourdomain.com -d '*.yourdomain.com'` : Spécifie le domaine et le domaine wildcard.
- `--keylength 4096` : Définit la longueur de la clé à 4096 bits.
- `--home /acme.sh` : Définit le répertoire home pour `acme.sh`.
- `--accountemail your-email@example.com` : Définit votre adresse e-mail de compte avec Let's Encrypt.

**Note :** Passer les identifiants API via la ligne de commande peut être insecure. Assurez-vous que votre système est sécurisé et nettoyez l'historique de votre shell si nécessaire.

### 3. Installer le certificat

Après l'émission du certificat, installez-le en utilisant la commande suivante :

```bash
docker exec acme_sh acme.sh \
  --install-cert -d yourdomain.com -d '*.yourdomain.com' \
    --key-file       /acme.sh/yourdomain.com/fullchain.cer.key \
    --fullchain-file /acme.sh/yourdomain.com/fullchain.cer \
    --home           /acme.sh
```

**Notes :**

- Cette commande utilise le conteneur `acme.sh` pour installer le certificat.
- Les fichiers de certificat et de clé sont enregistrés aux emplacements spécifiés.
- Puisque vous avez un service systemd qui surveille les changements de certificats et recharge HAProxy, vous n'avez pas besoin de spécifier un `--reloadcmd`.

### 4. Assurer la bonne nomination des fichiers

Assurez-vous que le fichier de clé est nommé `fullchain.cer.key` dans le répertoire des certificats. HAProxy peut automatiquement trouver la clé si elle est nommée correctement et située dans le même répertoire que le certificat.

### 5. Mettre à jour la configuration de HAProxy

Assurez-vous que votre `haproxy.cfg` pointe vers le fichier de certificat correct :

```haproxy
frontend LAN_Frontend
    bind *:443 ssl crt /etc/haproxy/certs/yourdomain.com/fullchain.cer ssl-min-ver TLSv1.3
    # ... reste de votre configuration ...
```

Remplacez `yourdomain.com` par votre nom de domaine réel.

### 6. Redémarrer HAProxy

Votre service systemd devrait automatiquement recharger HAProxy lorsque les fichiers de certificats changent. Cependant, vous pouvez redémarrer manuellement HAProxy pour vous assurer qu'il utilise le nouveau certificat.

```bash
docker restart haproxy
```

## Vérification

### 1. Vérifier les détails du certificat

Utilisez OpenSSL pour vérifier que HAProxy sert le nouveau certificat Let's Encrypt.

```bash
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -issuer -dates
```

**Sortie attendue :**

```
issuer=CN=R3,O=Let's Encrypt,C=US
notBefore=Nov 16 07:00:00 2024 GMT
notAfter=Feb 14 07:00:00 2025 GMT
```

### 2. Surveiller les journaux

Assurez-vous que HAProxy a rechargé avec succès en vérifiant ses journaux.

```bash
docker logs haproxy
```

Recherchez des entrées indiquant un rechargement réussi.

### 3. Tester le renouvellement automatique

Pour tester le renouvellement automatique, vous pouvez simuler le processus de renouvellement. Puisque `acme.sh` stocke vos identifiants API dans le fichier `account.conf` dans le répertoire `/acme.sh`, il peut renouveler les certificats sans avoir besoin de ressaisir les identifiants.

Exécutez la commande suivante :

```bash
docker exec acme_sh acme.sh \
  --renew -d yourdomain.com -d '*.yourdomain.com' \
  --force \
  --home /acme.sh
```

Surveillez les journaux du service systemd pour confirmer que HAProxy a rechargé.

```bash
sudo journalctl -u watch_certificates.service -f
```

Vous devriez voir des sorties indiquant que HAProxy a été rechargé.

## Meilleures pratiques de sécurité

- **Protéger les tokens API :** Ne divulguez pas votre Token API Cloudflare dans les fichiers de configuration ou le contrôle de version. Utilisez la ligne de commande pour entrer les informations sensibles lorsque nécessaire.
- **Utiliser des tokens API restreints :** Créez un Token API avec des permissions limitées (par exemple, permissions DNS:Edit pour des zones spécifiques) au lieu d'utiliser votre Clé API globale.
- **Définir des permissions de fichiers appropriées :** Restreignez l'accès aux fichiers sensibles comme les certificats et les clés.
- **Mettre à jour régulièrement les conteneurs :** Utilisez Watchtower pour maintenir vos conteneurs Docker à jour avec les derniers correctifs de sécurité.
- **Limiter l'exposition :** N'exposez que les ports et services nécessaires à Internet. Utilisez des pare-feu pour restreindre l'accès lorsque c'est possible.

## Licence

Ce projet est sous licence [MIT License](LICENSE).

---

**Avertissement :** Remplacez tous les noms de domaine exemples (`yourdomain.com`, `service1.yourdomain.com`, etc.) et les adresses IP (`192.168.1.10`, `192.168.2.20`, etc.) par vos domaines réels et les IP de vos serveurs. Assurez-vous que les informations sensibles telles que les clés API et les mots de passe sont sécurisées et non exposées dans des dépôts publics.

---

Si vous rencontrez des problèmes ou avez des questions, n'hésitez pas à ouvrir une issue ou à contacter le mainteneur.
