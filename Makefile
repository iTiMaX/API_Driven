# Makefile - API Driven Infrastructure
# Auteur: iTiMaX

# Inclusion des variables générées par setup.sh (ID instance, URL...)
-include .env.state

# Couleurs pour l'affichage
CYAN = \033[0;36m
RESET = \033[0m

.PHONY: help deploy install infra start stop status clean check-deps

help: ## Affiche la liste des commandes
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-15s$(RESET) %s\n", $$1, $$2}'

deploy: check-deps infra ## Installation des dependances et deploiement complet
	@echo "$(CYAN)Deploiement termine. Utilisez 'make start' ou 'make stop'.$(RESET)"

check-deps: ## Verification et installation des outils (jq, zip, awscli-local)
	@echo "$(CYAN)Verification des dependances systeme...$(RESET)"
	@which jq > /dev/null || (echo "Installation de jq..." && sudo apt-get update -qq && sudo apt-get install -y jq)
	@which zip > /dev/null || (echo "Installation de zip..." && sudo apt-get install -y zip)
	@pip show awscli-local > /dev/null || (echo "Installation de awscli-local..." && pip install awscli-local boto3)

infra: ## Execution du script de configuration setup.sh
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