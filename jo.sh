#!/usr/bin/env bash
JOSH_VERSION=0.1.0
if [[ "$1" = "--version" || "$1" = "-v" ]]; then
	echo $JOSH_VERSION
	exit 0
fi


PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS=$(cat << "EOF"
EOF
)

ADDITIONAL_APT_PACKAGES="git g++ make"

CONTAINER_NAME=$(basename "$(pwd)")


read_toml_value() {
    local file=$1
    local key=$2
    local value

    # Use awk to extract the value
    value=$(awk -F' = ' -v key="$key" '$1 == key {gsub(/"/, "", $2); print $2}' "$file")

    # Return the value
    echo "$value"
}

read_toml_latest_py_version() {
    local file=$1
    local key=$2
    local value

    # Use awk to extract the value
    value=$(read_toml_value "$file" "$key")

    # Extract version numbers and their preceding characters
    versions=$(echo "$value" | awk -F'[<>=,^]' '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]+(\.[0-9]+)?$/) print $i}' | sort -V)

    # Initialize variables
    highest_version=""
    lowest_version=""
    use_lowest=false

    # Iterate through versions to find the highest and lowest versions
    for version in $versions; do
        if [[ $value == *"<"$version ]]; then
            use_lowest=true
        elif [[ $value == *"="$version ]]; then
            highest_version=$version
        else
            if [[ -z $lowest_version ]]; then
                lowest_version=$version
            fi
            highest_version=$version
        fi
    done

    # Determine the version to use
    if $use_lowest; then
        echo "$lowest_version"
    else
        echo "$highest_version"
    fi
}

if [ -f pyproject.toml ]; then
	PYPROJECT_PYTHON_VERSION=$(read_toml_latest_py_version "pyproject.toml" "python")
	PYTHON_VERSION=$PYPROJECT_PYTHON_VERSION
	echo "Using Python version $PYTHON_VERSION from pyproject.toml"
else
	PYTHON_VERSION=3.10
	echo "No pyproject.toml found, using default Python version $PYTHON_VERSION"
fi
INSTALL_PATH=/usr/local/bin/jo.sh
SYMLINK_PATH=/usr/local/bin/josh
CONFIG_DOCKER_COMMANDS_FILE=~/.config/josh/dockerfile_commands


# create ~/.config/josh configuration
if [ ! -d ~/.config/josh ]; then
	mkdir -p ~/.config/josh
fi
if [ ! -f $CONFIG_DOCKER_COMMANDS_FILE ]; then
	touch $CONFIG_DOCKER_COMMANDS_FILE
fi

# read into PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS the contents of ~/.config/josh/docker_commands
CONFIG_PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS=""
if [ -f $CONFIG_DOCKER_COMMANDS_FILE ]; then
	CONFIG_PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS+="$(cat $CONFIG_DOCKER_COMMANDS_FILE)"
fi


cat << "EOF"
________                ______  
______(_)_____   __________  /_ 
_____  /_  __ \  __  ___/_  __ \
____  / / /_/ /___(__  )_  / / /
___  /  \____/_(_)____/ /_/ /_/ 
/___/                           
EOF

echo "Josh's Own SHell $JOSH_VERSION"
echo "A tool for managing Python environments with Docker."
echo "Image and container name (based on \$pwd): $CONTAINER_NAME"
echo Default Docker image: $PYTHON_VERSION
echo "Use '$0 help' for more information"
set -e
if [ "$1" = "run" ]; then
	DETACH_FLAG=""
	while [ $# -gt 0 ]; do
		case $1 in
			--detach|-d)
				DETACH_FLAG="-d"
				DETACH_DETAILS="-c \"tail -f /dev/null\""
				echo "Running in detached mode"
				shift
				;;
			*)
				shift
				;;
		esac
	done
	if [ -z "$DETACH_FLAG" ]; then
		DETACH_FLAG="-it"
	fi
	docker run \
		$DETACH_FLAG \
		--entrypoint /bin/bash \
		--rm \
		--name $CONTAINER_NAME \
		--volume $(pwd):/app \
		--platform linux/amd64 \
		-w /app \
		-v $HOME/.aws:/root/.aws \
		$CONTAINER_NAME $DETACH_DETAILS
		
elif [ "$1" = "stop" ]; then
	echo Stopping container \"$CONTAINER_NAME\"...
	docker container stop $CONTAINER_NAME
elif [ "$1" = "build" ]; then
	POETRY_INSTALL=""
	POETRY_FILES=""
	NO_CACHE=""
    while [ $# -gt 0 ]; do
        case $1 in
            --poetry-install)
                POETRY_INSTALL="RUN poetry install --no-interaction"
                POETRY_FILES="COPY pyproject.toml poetry.lock ./"
                shift
                ;;
            --no-cache)
                NO_CACHE="--no-cache-filter runtime"
                shift
                ;;
            --no-cache-all)
                NO_CACHE="--no-cache"
                shift
                ;;
            --tagv)
                if [ -n "$2" ]; then
                    PYTHON_VERSION=$2
                    shift 2
                else
                    echo "Error: --tagv requires an argument"
                    exit 1
                fi
                ;;
            *)
                shift
                ;;
        esac
    done
	if [ -f ~/.github_token.txt ]; then
		GITHUB_TOKEN_SECRET="--secret id=github_token,src=~/.github_token.txt"
		MOUNT_GITHUB_TOKEN_SECRET='RUN --mount=type=secret,id=github_token,uid=1000  git config --global url."https://\$(cat /run/secrets/github_token):@github.com/".insteadOf "https://github.com/"'
		echo "Injecting GitHub token secret into build..."
	else
		GITHUB_TOKEN_SECRET=""
		MOUNT_GITHUB_TOKEN_SECRET=""
		echo "(No GitHub token found at ~/.github_token.txt)"
	fi
	if [ -n "${NEXUS_PYPI_URL}" ]; then
		echo -e "export NEXUS_PYPI_URL=$NEXUS_PYPI_URL\nexport NEXUS_PYPI_USER=$NEXUS_PYPI_USER\nexport NEXUS_PYPI_PASSWORD='$NEXUS_PYPI_PASSWORD'" > /tmp/.env.nexus
		NEXUS_SECRET="--secret id=nexus,src=/tmp/.env.nexus"
		echo "Injecting Nexus PyPI secret into build..."
		NEXUS_POETRY_CONFIG=""
		NEXUS_POETRY_CONFIG=$(cat <<- "EOF"
				RUN --mount=type=secret,id=nexus,uid=1000 . /run/secrets/nexus \
					&& poetry config repositories.nexus $NEXUS_PYPI_URL \
					&& poetry config http-basic.nexus $NEXUS_PYPI_USER $NEXUS_PYPI_PASSWORD
			EOF
		)
	else
		NEXUS_SECRET=""
		NEXUS_POETRY_CONFIG=""
		echo "(No Nexus PyPI secret found)"
	fi

	echo "jo.sh is currently hard coded to to use the following secret values (if they exist!):"
	echo "  - github_token: Used to authenticate with GitHub, located at ~/.github_token.txt"
	echo "  - Environment variables: NEXUS_PYPI_URL, NEXUS_PYPI_USER, NEXUS_PYPI_PASSWORD"
	echo Building with image python:$PYTHON_VERSION
	docker build -t $CONTAINER_NAME $GITHUB_TOKEN_SECRET $NEXUS_SECRET $NO_CACHE --platform linux/amd64 . -f-<<-EOF
	FROM python:$PYTHON_VERSION as builder
	RUN apt-get update && apt-get install -y curl $ADDITIONAL_APT_PACKAGES
	RUN pip install --upgrade pip setuptools wheel mypy black
	##############################################INSTALL POETRY##############################################
	ENV POETRY_HOME="/opt/poetry" \
		POETRY_VIRTUALENVS_CREATE=false \
		POETRY_VIRTUALENVS_IN_PROJECT=false \
		POETRY_NO_INTERACTION=1
	ENV PATH="\$PATH:\$POETRY_HOME/bin"
	RUN curl -SL https://install.python-poetry.org | python - \
		&& poetry --version \
		&& poetry config virtualenvs.create false
	##############################################INSTALL POETRY##############################################
	FROM builder AS runtime
	$MOUNT_GITHUB_TOKEN_SECRET
	$NEXUS_POETRY_CONFIG
	$PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS
	$CONFIG_PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS

	$POETRY_FILES
	$POETRY_INSTALL
	ENTRYPOINT [ "bash" ]
	EOF
elif [ "$1" = "install" ]; then

	if [ "$0" != $INSTALL_PATH ]; then
		cp $0 $INSTALL_PATH
		ln -sf $INSTALL_PATH $SYMLINK_PATH
		chmod a+rx $INSTALL_PATH
		echo "Installed josh to $INSTALL_PATH. You can call it with 'josh' or 'jo.sh'"
	else
		echo "Cannot install this script to $INSTALL_PATH because this is already $INSTALL_PATH"
	fi
elif [ "$1" = "uninstall" ]; then
	# are you sure prompt
	read -p "Are you sure you want to uninstall josh? (y/n) " -n 1 -r
	echo   # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm $INSTALL_PATH
		rm $SYMLINK_PATH
		echo "Uninstalled josh"
	fi
	exit 0
elif [ "$1" = "clean" ]; then
	echo Attempting to clean up container and image...
	docker container stop $CONTAINER_NAME || true
	docker container rm $CONTAINER_NAME || true
	docker image rm $CONTAINER_NAME || true
	echo Clean up complete.
elif [[ "$1" == *.sh ]]; then
	docker run \
		-it \
		--rm \
		--name $CONTAINER_NAME \
		--volume $(pwd):/app \
		--platform linux/amd64 \
		-w /app \
		-v $HOME/.aws:/root/.aws \
		$CONTAINER_NAME "${@:1}"
elif [[ "$1" == *.py ]]; then
	docker run \
		-it \
		-- rm \
		--name $CONTAINER_NAME \
		--volume $(pwd):/app \
		--platform linux/amd64 \
		-w /app \
		-v $HOME/.aws:/root/.aws \
		--entrypoint python \
		$CONTAINER_NAME "${@:1}"
elif [[ "$1" == *help ]]; then
	echo "Usage: $0 [COMMAND] [OPTIONS]"
	echo "Commands:"
	echo "  run: Launch a stateless interactive shell with Python and Poetry installed"
	echo "    --detach, -d: Run the container in the background"
	echo "  stop: Stop the container if running"
	echo "  build: Build the container"
	echo "    --poetry-install: Install the dependencies in the pyproject.toml file into the image"
	echo "    --no-cache: Do not use cached layers of user specific content (poetry packages, Dockerfile commands from $CONFIG_DOCKER_COMMANDS_FILE)"
	echo "    --no-cache-all: Do not use cache at all when building the image, this includes the base image and all layers"
	echo "    --tagv [TAG VERSION]: Specify a Python docker image version (default: pyproject.toml's spec or $PYTHON_VERSION). Example: --tagv 3.9"
	echo "  clean: Stop and remove the container and image"
	echo "  install: Install this script to /usr/local/bin/jo.sh and create a "josh" symlink (may require sudo)"
	echo "  uninstall: Uninstall this script from /usr/local/bin/jo.sh (may require sudo)"
	echo "  help: Show this help message"
	echo "Options:"
	echo "  --version, -v: Show the version of jo.sh"
# if not empty, unrecognized 
elif [ -n "$1" ]; then
	echo "Unrecognized command: $1"
	echo "Use '$0 help' for more information"
else
	echo Launching a stateless interactive shell with Python and Poetry installed. Python version: $PYTHON_VERSION
	{
	  docker run \
		--rm \
		-it \
		--name $CONTAINER_NAME \
		--volume $(pwd):/app \
		--platform linux/amd64 \
		-w /app \
		-v $HOME/.aws:/root/.aws \
		$CONTAINER_NAME
	} || {
		echo Container already exists. Attaching to existing container..
		docker exec -it $CONTAINER_NAME bash
	}
fi
