.PHONY: clean down up perms rmq-perms

DOCKER_FRESH ?= false
RABBITMQ_DOCKER_TAG ?= rabbitmq:3.12-management

clean: perms
	git clean -xffd

down:
	docker compose down

up: rmq-perms
ifeq ($(DOCKER_FRESH),true)
	docker compose build --no-cache --pull --build-arg RABBITMQ_DOCKER_TAG=$(RABBITMQ_DOCKER_TAG)
else
	docker compose build --build-arg RABBITMQ_DOCKER_TAG=$(RABBITMQ_DOCKER_TAG)
endif
	docker compose up

perms:
	sudo chown -R "$$(id -u):$$(id -g)" data log

rmq-perms:
	sudo chown -R '999:999' data log

check:
	curl -4su 'guest:guest' 'localhost:15672/api/queues/%2F' | jq '.'
