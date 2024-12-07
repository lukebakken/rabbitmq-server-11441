#!/usr/bin/env bash

set -o errexit
set -o pipefail
# set -o xtrace

docker_fresh='false'
if [[ "$1" == 'fresh' ]]
then
    docker_fresh='true'
fi
readonly docker_fresh

set -o nounset

function now
{
    date --rfc-3339=sec
}

for svc in rmq0 rmq1 rmq2
do
    echo "$(now) [INFO] upgrading '$svc'"

    docker compose exec "$svc" /opt/rabbitmq/sbin/rabbitmqctl enable_feature_flag all
    docker compose exec "$svc" /opt/rabbitmq/sbin/rabbitmq-upgrade drain

    echo "$(now) [INFO] stopping '$svc'"
    set +o errexit
    docker compose exec "$svc" /opt/rabbitmq/sbin/rabbitmqctl shutdown
    set -o errexit
    echo "$(now) [INFO] '$svc' is stopped!"

    # NB: use --no-cache if Dockerfile or other resources in rmq/ changed
    if [[ $docker_fresh == 'true' ]]
    then
        docker compose build --no-cache --pull \
            --build-arg 'RABBITMQ_DOCKER_TAG=rabbitmq:3.13-management' \
            --build-arg "SVC=$svc" "$svc"
    else
        docker compose build \
            --build-arg 'RABBITMQ_DOCKER_TAG=rabbitmq:3.13-management' \
            --build-arg "SVC=$svc" "$svc"
    fi

    echo "$(now) [INFO] starting '$svc'"
    docker compose up --detach "$svc"

    set +o errexit
    sleep 2
    while ! docker compose exec "$svc" /opt/rabbitmq/sbin/rabbitmqctl await_startup
    do
        sleep 1
    done
    set -o errexit

    echo "$(now) [INFO] '$svc' is started!"
done

for svc in rmq0 rmq1 rmq2
do
    echo "$(now) [INFO] enabling feature flags: '$svc'"
    docker compose exec "$svc" /opt/rabbitmq/sbin/rabbitmqctl enable_feature_flag all
done
