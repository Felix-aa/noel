ROOT_DIR       := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL          := $(shell which bash)
PROJECT_NAME    = noel
ARGS            = $(filter-out $@,$(MAKECMDGOALS))

.SILENT: ;               # no need for @
.ONESHELL: ;             # recipes execute in same shell
.NOTPARALLEL: ;          # wait for this target to finish
.EXPORT_ALL_VARIABLES: ; # send all vars to shell
default: help-default;   # default target
Makefile: ;              # skip prerequisite discovery

help-default help:
	@echo "                          ====================================================================="
	@echo "                          Help & Check Menu"
	@echo "                          ====================================================================="
	@echo "                   help: Shows Help menu"
	@echo "                   status: Shows containers status"
	@echo "                          ====================================================================="
	@echo "                          Main Menu"
	@echo "                          ====================================================================="
	@echo "                   up: Create and start application in detached mode (in the background)"
	@echo "                   stop: Stop application"
	@echo "                   root:  Login to the 'app' container as 'root' user"
	@echo "                   build: Build or rebuild services"
	@echo "                   logs: Attach to logs"
	@echo "                   test: Runs tests"
	@echo "                   test-with-analysis: Runs test and code analysis"
	@echo "                   stop-test: Shutdowns a test environment"
	@echo "                   load-data: Loads data fixtures into database"
	@echo ""

build:
	docker-compose --project-name $(PROJECT_NAME) build

up:
	docker-compose --project-name $(PROJECT_NAME) up -d
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) ps -q app) sh -c "/app/bin/stop-workers.sh"

stop:
	docker-compose --project-name $(PROJECT_NAME) stop

down:
	docker-compose --project-name $(PROJECT_NAME) down

status:
	docker-compose --project-name $(PROJECT_NAME) ps

logs:
	docker logs -f $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose.yml ps -q app)

root:
	docker exec -it -u root $$(docker-compose --project-name $(PROJECT_NAME) ps -q app) /bin/bash

testenv:
	docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml down
	docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml build --no-cache
	docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml up -d
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "composer --working-dir=/app wait-for-mysql"

test: testenv
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "composer --working-dir=/app install -o"
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "composer --working-dir=/app app.preparation.test"
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "php -d pcov.enabled=1 -d memory_limit=-1 vendor/bin/phpunit --colors=auto"

test-with-analysis: testenv
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "composer --working-dir=/app install -o"
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "composer --working-dir=/app app.preparation.test"
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "sed -i 's/^xdebug.mode=debug/xdebug.mode=coverage/g' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini"
	docker cp sonar-scanner.properties $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app):/opt/sonar/scanner/conf/sonar-scanner.properties
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "php -d pcov.enabled=1 -d memory_limit=-1 vendor/bin/phpunit --log-junit tests/_output/phpunit-report.xml --coverage-clover tests/_output/coverage.xml && sonar-scanner"

stop-test:
	docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml stop

load-data:
	docker exec -u root $$(docker-compose --project-name $(PROJECT_NAME) -f docker-compose_test.yml ps -q app) sh -c "php ./bin/console doctrine:fixtures:load -n"

check-php-standard: 
	docker exec -it -u root $$(docker-compose --project-name $(PROJECT_NAME) ps -q app) sh -c "vendor/bin/phpstan analyse"

%:
	@:
