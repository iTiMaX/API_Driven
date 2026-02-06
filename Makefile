# Makefile - API Driven Infrastructure
# Auteur: iTiMaX

-include .env.state

CYAN = \033[0;36m
RESET = \033[0m

.PHONY: help deploy install infra start stop status clean check-deps

help: ## Affiche la liste des commandes
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-15s$(RESET) %s\n", $$1, $$2}'

deploy: check-deps infra ## Installation et deploiement complet
	@echo "$(CYAN)Deploiement termine. Utilisez 'make start' ou 'make stop'.$(RESET)"

check-deps: ## Verification et installation des outils
	@echo "$(CYAN)Verification des dependances systeme...$(RESET)"
	@which jq > /dev/null || (echo "Installation de jq..." && sudo apt-get update -qq && sudo apt-get install -y jq)
	@which zip > /dev/null || (echo "Installation de zip..." && sudo apt-get install -y zip)
	@# CORRECTION ICI : Ajout de awscli (le moteur) en plus de awscli-local
	@pip show awscli > /dev/null || (echo "Installation de awscli, localstack et outils..." && pip install awscli awscli-local boto3 localstack)

infra: ## Execution du script de configuration
	@./setup.sh

start: ## Demarre l'instance EC2 via l'API
	@if [ -z "$(API_URL)" ]; then echo "Erreur: Lancez 'make deploy' avant."; exit 1; fi
	@echo "$(CYAN)Demande de demarrage pour $(INSTANCE_ID)...$(RESET)"
	@curl -s -X POST "$(API_URL)" \
		-H "Content-Type: application/json" \
		-d '{"action": "start", "instance_id": "$(INSTANCE_ID)"}' | jq .

stop: ## Arrete l'instance EC2 via l'API
	@if [ -z "$(API_URL)" ]; then echo "Erreur: Lancez 'make deploy' avant."; exit 1; fi
	@echo "$(CYAN)Demande d'arret pour $(INSTANCE_ID)...$(RESET)"
	@curl -s -X POST "$(API_URL)" \
		-H "Content-Type: application/json" \
		-d '{"action": "stop", "instance_id": "$(INSTANCE_ID)"}' | jq .

status: ## Recupere l'etat de l'instance via l'API
	@if [ -z "$(API_URL)" ]; then echo "Erreur: Lancez 'make deploy' avant."; exit 1; fi
	@echo "$(CYAN)Verification du statut de $(INSTANCE_ID)...$(RESET)"
	@curl -s -X POST "$(API_URL)" \
		-H "Content-Type: application/json" \
		-d '{"action": "status", "instance_id": "$(INSTANCE_ID)"}' | jq .

clean: ## Nettoyage des fichiers temporaires
	@rm -f function.zip .env.state lambda_function.py
	@echo "Fichiers temporaires supprimes."