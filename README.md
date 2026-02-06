# Séquence 10 : API-DRIVEN INFRASTRUCTURE

Ce projet répond à l'atelier "API-Driven Infrastructure". L'objectif est de piloter des ressources d'infrastructure (instances EC2) via des appels HTTP standard, en utilisant une architecture Serverless (API Gateway + Lambda) émulée par LocalStack dans un environnement GitHub Codespaces.

## Architecture

Le système repose sur le flux suivant :

1. **Client** : Envoie une requête HTTP (POST via Makefile ou GET via Navigateur).
2. **API Gateway** : Configurée avec la méthode `ANY`, elle reçoit la requête et la transmet à la Lambda.
3. **AWS Lambda** : Exécute le code Python (Boto3). Elle analyse soit le corps de la requête (JSON), soit les paramètres d'URL (Query String) pour déterminer l'action.
4. **EC2 (LocalStack)** : L'instance est démarrée, arrêtée ou consultée.

## Automatisation

Le projet inclut une chaîne d'automatisation complète via un `Makefile` et un script `setup.sh`. Cette approche garantit :

* **Idempotence** : Le script peut être relancé sans casser l'infrastructure existante (vérification de l'existence des ressources avant création).
* **Configuration dynamique** : L'URL publique du Codespace est détectée automatiquement et injectée dans le code de la Lambda au moment du déploiement.

## Guide d'utilisation

### 1. Installation et Déploiement

Une seule commande permet d'installer les dépendances système (`jq`, `awscli-local`, `zip`) et de déployer l'infrastructure complète.

```bash
make deploy
```

*En fin de déploiement, le script affiche les URLs directes pour tester depuis un navigateur.*

### 2. Pilotage via CLI (Makefile)

Utilisez les commandes suivantes pour interagir avec l'API en ligne de commande :

| Commande | Description |
| --- | --- |
| `make start` | Envoie une requête POST pour **démarrer** l'instance. |
| `make stop` | Envoie une requête POST pour **arrêter** l'instance. |
| `make status` | Interroge l'API pour récupérer l'**état actuel**. |

### 3. Pilotage via Navigateur (Method GET)

L'API supporte les requêtes GET. Vous pouvez copier-coller les liens générés par le script `make deploy` ou construire l'URL manuellement :

Format : `https://<URL_CODESPACE>/restapis/<API_ID>/prod/_user_request_/manage?action=<ACTION>&instance_id=<ID>`

Actions valides : `start`, `stop`, `status`.

### 4. Nettoyage

Pour supprimer les fichiers temporaires locaux :

```bash
make clean
```

## Structure du projet

* **Makefile** : Orchestrateur des commandes.
* **setup.sh** : Script de déploiement. Configure API Gateway en mode `ANY` et génère le code Lambda pour supporter le double mode d'entrée (JSON Body / Query Params).
* **.gitignore** : Exclusion des fichiers temporaires.
* **lambda_function.py** : (Généré) Logique métier Boto3.

## Choix techniques

**Support Hybride GET/POST**
Pour faciliter les tests et la démonstration, l'API Gateway est configurée avec la méthode `ANY`. La fonction Lambda a été adaptée pour lire la priorité des instructions :

1. Si un corps JSON est présent (appel via `curl`/`make`), il est utilisé.
2. Sinon, les paramètres d'URL (`queryStringParameters`) sont utilisés (appel via navigateur).

**Contournement Réseau Docker**
Pour respecter la contrainte "API-Driven", la Lambda ne s'adresse pas à `localhost` (réseau interne inaccessible depuis le conteneur Lambda). Le script injecte l'URL publique du Codespace (`github.dev`) dans le client Boto3, simulant un accès externe réaliste.