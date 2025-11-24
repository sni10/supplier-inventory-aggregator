##################
# Config
##################

ENVIRONMENT ?= test
ENV_FILE = ./docker/config-envs/$(ENVIRONMENT)/.env.$(ENVIRONMENT)
COMPOSE_FILES = -f ./docker-compose.yml -f ./docker/config-envs/$(ENVIRONMENT)/docker-compose.override.yml
CONTAINER_NAME ?= php-sda
DOCKER_EXEC = docker exec -it $(CONTAINER_NAME)
DOCKER_EXEC_WWW = docker exec -it -u www-data $(CONTAINER_NAME)

##################
# Docker Compose
##################

dc_build:
	docker-compose $(COMPOSE_FILES) build --pull

dc_up:
	docker-compose $(COMPOSE_FILES) up -d --build --force-recreate --remove-orphans

dc_down:
	docker-compose $(COMPOSE_FILES) down --volumes --rmi local --remove-orphans

dc_restart:
	docker-compose $(COMPOSE_FILES) down --volumes --rmi local --remove-orphans
	docker-compose $(COMPOSE_FILES) up -d --build --force-recreate

dc_logs:
	docker-compose $(COMPOSE_FILES) logs -f

dc_ps:
	docker-compose $(COMPOSE_FILES) ps

dc_exec:
	docker-compose $(COMPOSE_FILES) exec -u www-data php-fpm bash

##################
# Logs (Debug)
##################

logs_app:
	$(DOCKER_EXEC) tail -f /var/log/supervisor/symfony_command.out.log

logs_app_err:
	$(DOCKER_EXEC) tail -f /var/log/supervisor/symfony_command.err.log

logs_supervisor:
	$(DOCKER_EXEC) tail -f /var/log/supervisord.log

logs_php:
	$(DOCKER_EXEC) tail -f /var/log/php_errors.log

##################
# Symfony Console
##################

console:
	$(DOCKER_EXEC_WWW) php bin/console $(cmd)

consume:
	$(DOCKER_EXEC_WWW) php bin/console app:consume

cache_clear:
	$(DOCKER_EXEC_WWW) php bin/console cache:clear

##################
# Composer
##################

composer_install:
	$(DOCKER_EXEC_WWW) composer install --no-interaction --prefer-dist

composer_update:
	$(DOCKER_EXEC_WWW) composer update --no-interaction --prefer-dist

composer_dump:
	$(DOCKER_EXEC_WWW) composer dump-autoload -o

##################
# Tests
##################

test:
	$(DOCKER_EXEC_WWW) php vendor/bin/phpunit

test_coverage:
	$(DOCKER_EXEC_WWW) php vendor/bin/phpunit --coverage-html var/coverage

test_filter:
	$(DOCKER_EXEC_WWW) php vendor/bin/phpunit --filter=$(filter)

##################
# Cleanup
##################

docker_clean:
	docker system prune -af --volumes
	docker builder prune -af
	docker image prune -af
