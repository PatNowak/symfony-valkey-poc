#!/usr/bin/env bash

# Note! Changes here should also be made to sirvoy-docker.ps1 so our platform-specific scripts are in sync!

OS=$(uname -s)

unify_service_names_for_docker () {
containers=$1
case "$containers" in
"www") containers="app_www" ;;
"lb") containers="app_lb" ;;
"redis") containers="app_redis" ;;
"db-main") containers="app_db_main" ;;
"db-archive") containers="app_db_archive" ;;
"mock") containers="app_mock" ;;
esac
}

unify_service_names_for_compose () {
containers=$1
case "$containers" in
"app_www") containers="www" ;;
"app_db_main") containers="db-main" ;;
"app_db_archive") containers="db-archive" ;;
"app_redis") containers="redis" ;;
"app_lb") containers="lb" ;;
"app_mock") containers="mock" ;;
esac
}

fix_networking_for_macos () {
# Only for Mac we have to adjust networking, so we can reach containers from the host
  if [[ "${OS}" == "Darwin" ]]; then
    port_80=$(docker port app_lb 80/tcp)
    port_443=$(docker port app_lb 443/tcp)
    PARENT_DIR=$(dirname $(pwd))
    sudo python3 "$PARENT_DIR/sirvoy-engineering/resources/scripts/local_environment/mac_networking_issue_fixer.py" $port_80 $port_443
  fi
}

EXTRA_SETUP_AFTER_UP=('app_www' 'app_mock')
EXTRA_SETUP_AFTER_RELOAD=('app_www' 'app_mock')
IS_INTERACTIVE=0

GIT_REPO=$(git rev-parse --show-toplevel 2>&1)

# in docker-compose.yml we specify network's name to be "net", but it's always combined with the folder's name
# hence it's e.g. "sirvoy-project-desktop_net" for Johan and "sirvoy-project_net" for Patryk
FOLDER_NAME=$(basename "$GIT_REPO")

if [[ $? != 0 ]]; then
    echo "Fatal error - could not find root directory of git repository!"
    exit 1
fi

# first argument
case "$1" in
    "status") docker compose ps -a
    ;;
    "stats") docker stats
    ;;
    "names") docker ps --format '{{.Names}}'
    ;;
    "logs")
        unify_service_names_for_docker $2
        docker logs $containers
    ;;
    "up")
        containers=$2
        www_image_present=$(docker image ls | grep "^sirvoy-project-www")

        # make sure always vendor and node_modules folders are always present
        mkdir -p "$GIT_REPO/application/vendor"
        mkdir -p "$GIT_REPO/application/node_modules"

        # check do we have www image
        # if not, build it explicitly before anything else and pass host user's id in the invisible way for developers
        if [[ ${#www_image_present}  -eq 0 ]]; then
            cd $GIT_REPO && docker compose build --progress=plain --build-arg UID=$(id -u) www
        fi

        mock_image_present=$(docker image ls | grep "^sirvoy-project-mock")
        # check do we have mock image
        # if not, build it explicitly before anything else and pass host user's id in the invisible way for developers
        if [[ ${#mock_image_present}  -eq 0 ]]; then
            cd $GIT_REPO && docker compose build --progress=plain --build-arg UID=$(id -u) mock
        fi

        # compose works with www, lb etc.
        unify_service_names_for_compose $containers

        cd $GIT_REPO && docker compose up -d $containers # -d is always used for `detached` mode - basically - we do it all in background
        # we have folders like app_www etc.
        unify_service_names_for_docker $containers

        # always run `post_install.sh` file for every supported container
        for i in "${EXTRA_SETUP_AFTER_UP[@]}"; do
            if [[ "$containers" == '' || "$containers" == "$i" ]]; then
                bash "$GIT_REPO/resources/docker/$i/post_install.sh"
            fi
        done;

        fix_networking_for_macos
    ;;
    "reload")
        # compose works with www, lb etc.
        unify_service_names_for_compose $2

        cd $GIT_REPO && docker compose restart $containers

        unify_service_names_for_docker $containers
        # always run `post_reload.sh` file for every supported container
        for i in "${EXTRA_SETUP_AFTER_RELOAD[@]}"; do
            if [[ "$containers" == '' || "$containers" == "$i" ]]; then
                bash "$GIT_REPO/resources/docker/$i/post_reload.sh"
            fi
        done;

        fix_networking_for_macos
    ;;
    "fix")
        fix_networking_for_macos
    ;;
    "stop")
        unify_service_names_for_compose $2

        docker compose stop $containers
    ;;
    "destroy")
        unify_service_names_for_compose $2

        docker compose kill $containers
        docker compose rm --force $containers
    ;;
    "destroy-all")
        unify_service_names_for_compose $2
        docker compose down --volumes --rmi=all $containers
    ;;
    "fresh-db")
        docker compose kill db-main
        docker compose kill db-archive
        docker compose rm --force db-main
        docker compose rm --force db-archive
        docker compose up -d db-main
        docker compose up -d db-archive

        cd $GIT_REPO && docker compose restart www
        bash "$GIT_REPO/resources/docker/app_www/post_reload.sh"
        fix_networking_for_macos
    ;;
    "cleanup")
        docker system prune -a --volumes -f
    ;;
    "bash")
        unify_service_names_for_docker $2
        docker exec -it $containers bash
    ;;
    "all-tests")
        bash "$GIT_REPO/resources/travis/run_tests_script.sh" local
    ;;
    "app_lb" | "lb")
        # choose proper action to take on app_lb
        case "$2" in
            "new-cert") command="python3 /docker/resources/scripts/python_scripts/certificates/letsencrypt.py mode=new repo=$3" ;;
            "renew-cert") command="python3 /docker/resources/scripts/python_scripts/certificates/letsencrypt.py repo=$3" ;;
            "ngrok") command="./docker/resources/app_lb/ngrok.sh $3" ;;
            *) echo "ERROR: Command not recognized!"; exit 1 ;;
        esac

        # run command here
        echo $command
        docker exec -it app_lb bash -c "$command"
    ;;
    *) # catch all for help and www commands
    # use $* to pass all args here, $@ doesn't work

    # handle case for translation-update before going to container
    if [[ "$2" == "translation-update" ]]; then
        scp sirvoy-app-service-bugday:/tmp/sirvoy_translations/$3 $PWD/application/translations.zip
    fi

    # we want to preserve double quotes strings
    PARAMS=""
    for PARAM in "$@"
    do
      PARAMS="${PARAMS} \"${PARAM}\""
    done

    # Only locally commands are interactive
    source $GIT_REPO/.env
    if [[ $PLATFORM == "Ubuntu" ]]; then
        docker exec -it app_www bash -c  "python3 ./resources/scripts/python_scripts/local_environment/commands.py $PARAMS"
    else
      docker exec -t app_www bash -c "python3 ./resources/scripts/python_scripts/local_environment/commands.py $PARAMS"
    fi
esac
