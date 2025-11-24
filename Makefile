##################
# Config
##################

APP_ENV ?= test
ENV_FILE = .env.$(APP_ENV)
COMPOSE_FILES = -f docker-compose.yml -f docker/config-envs/$(APP_ENV)/docker-compose.override.yml
DC = docker compose --env-file $(ENV_FILE) $(COMPOSE_FILES)
CONTAINER_NAME = php-sda

# Production config (без override)
DC_PROD = docker compose

##################
# Docker Compose - Test/Dev APP_ENV
##################

.PHONY: build up down restart logs ps shell

build:
	$(DC) build

up:
	$(DC) up -d

down:
	$(DC) down -v

restart: down up

logs:
	$(DC) logs -f

ps:
	$(DC) ps

shell:
	$(DC) exec -u www-data $(CONTAINER_NAME) bash

##################
# Docker Compose - Production
##################

.PHONY: prod-build prod-up prod-down prod-restart prod-logs

prod-build:
	$(DC_PROD) build

prod-up:
	$(DC_PROD) up -d

prod-down:
	$(DC_PROD) down -v

prod-restart: prod-down prod-up

prod-logs:
	$(DC_PROD) logs -f

##################
# Logs (Debug)
##################

.PHONY: logs-app logs-app-err logs-supervisor logs-php

logs-app:
	$(DC) exec $(CONTAINER_NAME) tail -f /var/log/supervisor/symfony_command.out.log

logs-app-err:
	$(DC) exec $(CONTAINER_NAME) tail -f /var/log/supervisor/symfony_command.err.log

logs-supervisor:
	$(DC) exec $(CONTAINER_NAME) tail -f /var/log/supervisord.log

logs-php:
	$(DC) exec $(CONTAINER_NAME) tail -f /var/log/php_errors.log

##################
# Symfony Console
##################

.PHONY: console consume cache-clear

console:
	$(DC) exec -u www-data $(CONTAINER_NAME) php bin/console $(CMD)

consume:
	$(DC) exec -u www-data $(CONTAINER_NAME) php bin/console app:consume

cache-clear:
	$(DC) exec -u www-data $(CONTAINER_NAME) php bin/console cache:clear

##################
# Testing
##################

.PHONY: test test-coverage test-html test-unit test-filter

test:
	$(DC) exec -u www-data $(CONTAINER_NAME) php vendor/bin/phpunit --colors=always --testdox

test-coverage:
	$(DC) exec -u www-data $(CONTAINER_NAME) php vendor/bin/phpunit --coverage-text --colors=always --testdox

test-html:
	$(DC) exec -u www-data $(CONTAINER_NAME) php vendor/bin/phpunit --coverage-html=var/coverage

test-unit:
	$(DC) exec -u www-data $(CONTAINER_NAME) php vendor/bin/phpunit tests/Unit/ --colors=always --testdox

# Usage: make test-filter FILTER=testName
test-filter:
	$(DC) exec -u www-data $(CONTAINER_NAME) php vendor/bin/phpunit --filter=$(FILTER) --colors=always --testdox

##################
# Composer
##################

.PHONY: composer-install composer-update composer-dump

composer-install:
	$(DC) exec -u www-data $(CONTAINER_NAME) composer install --no-interaction --prefer-dist

composer-update:
	$(DC) exec -u www-data $(CONTAINER_NAME) composer update --no-interaction --prefer-dist

composer-dump:
	$(DC) exec -u www-data $(CONTAINER_NAME) composer dump-autoload -o

##################
# Setup & Init
##################

.PHONY: init setup

# First-time setup for test APP_ENV
init: build up
	@echo "Test APP_ENV initialized successfully!"

# Quick setup (assumes containers already exist)
setup: up
	@echo "APP_ENV ready!"

##################
# Cleanup
##################

.PHONY: clean docker-prune

clean:
	$(DC) down -v --rmi local --remove-orphans

docker-prune:
	docker system prune -af --volumes
	docker builder prune -af

##################
# Help
##################

.PHONY: help

help:
	@echo "Usage: make [target] [APP_ENV=test|prod]"
	@echo ""
	@echo "Docker (Test/Dev):"
	@echo "  build          Build containers"
	@echo "  up             Start containers"
	@echo "  down           Stop and remove containers"
	@echo "  restart        Restart containers"
	@echo "  logs           Follow container logs"
	@echo "  ps             List containers"
	@echo "  shell          Open bash in PHP container"
	@echo ""
	@echo "Docker (Production):"
	@echo "  prod-build     Build production containers"
	@echo "  prod-up        Start production containers"
	@echo "  prod-down      Stop production containers"
	@echo "  prod-restart   Restart production containers"
	@echo ""
	@echo "Logs (Debug):"
	@echo "  logs-app       Application stdout logs"
	@echo "  logs-app-err   Application stderr logs"
	@echo "  logs-supervisor Supervisord logs"
	@echo "  logs-php       PHP error logs"
	@echo ""
	@echo "Testing:"
	@echo "  test           Run all tests"
	@echo "  test-coverage  Run tests with coverage report"
	@echo "  test-html      Generate HTML coverage report"
	@echo "  test-unit      Run unit tests only"
	@echo "  test-filter    Run specific test (FILTER=testName)"
	@echo ""
	@echo "Symfony Console:"
	@echo "  console        Run console command (CMD=...)"
	@echo "  consume        Start Kafka consumer"
	@echo "  cache-clear    Clear Symfony cache"
	@echo ""
	@echo "Composer:"
	@echo "  composer-install  Install dependencies"
	@echo "  composer-update   Update dependencies"
	@echo "  composer-dump     Dump autoload"
	@echo ""
	@echo "Setup:"
	@echo "  init           Full initialization (build + up)"
	@echo "  setup          Quick setup (up)"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean          Remove containers and images"
	@echo "  docker-prune   Full Docker cleanup"
