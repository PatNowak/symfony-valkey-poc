#!/usr/bin/env bash

# first argument
case "$1" in
    "status")
      docker compose -f docker compose-redis.yml ps -a
      docker compose -f docker compose-valkey.yml ps -a
    ;;

    "redis")
      docker-compose -f docker compose-redis.yml up -d
    ;;
    "valkey")
      docker-compose -f docker compose-valkey.yml up -d
    ;;

    "down")
      docker compose -f docker compose-valkey.yml down --volumes --rmi=all
      docker compose -f docker compose-redis.yml down --volumes --rmi=all
    ;;

    "6.4")
      docker exec -it symfony-valkey-poc-php-apache-1 bash -c "cd app && composer require symfony/lock ^6.4"
    ;;

    "7.2")
      docker exec -it symfony-valkey-poc-php-apache-1 bash -c "cd app && composer require symfony/lock ^7.2"
    ;;
esac
