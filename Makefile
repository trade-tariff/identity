IMAGE_NAME := trade-tariff-identity
COMMON_ENV := --env-file ".env.development"

default: build run

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run \
		--network=host \
		--rm \
		--name $(IMAGE_NAME) \
		$(COMMON_ENV) \
		$(IMAGE_NAME)

clean:
	docker rmi $(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--name $(IMAGE_NAME)-shell \
		$(COMMON_ENV) \
		--no-healthcheck \
		-it $(IMAGE_NAME) /bin/sh
