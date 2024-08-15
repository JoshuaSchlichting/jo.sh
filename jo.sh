#!/usr/bin/env bash

PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS=$(cat << "EOF"
EOF
)

ADDITIONAL_APT_PACKAGES="git g++ make"

CONTAINER_NAME=$(basename "$(pwd)")
PYTHON_IMAGE=3.10-slim-buster
cat << "EOF"
________                ______  
______(_)_____   __________  /_ 
_____  /_  __ \  __  ___/_  __ \
____  / / /_/ /___(__  )_  / / /
___  /  \____/_(_)____/ /_/ /_/ 
/___/                           
EOF

echo "Josh's Own SHell v0.0.2-alpha"
echo "A tool for managing Python environments with Docker."
echo "Image and container name (based on \$pwd): $CONTAINER_NAME"
echo Docker image: $PYTHON_IMAGE
echo "Use '$0 help' for more information"
set -e
if [ "$1" = "build" ]; then
	POETRY_INSTALL=""
	POETRY_FILES=""
	NO_CACHE=""
	for arg in "$@"; do
		case $arg in
			--poetry-install)
				POETRY_INSTALL="RUN poetry install --no-interaction"
				POETRY_FILES="COPY pyproject.toml poetry.lock ./"
				;;
			--no-cache)
				NO_CACHE="--no-cache"
				;;
		esac
	done

	if [ -f ~/.github_token.txt ]; then
		GITHUB_TOKEN_SECRET="--secret id=github_token,src=~/.github_token.txt"
	else
		GITHUB_TOKEN_SECRET=""
	fi
	if [ -n "${NEXUS_PYPI_URL}" ]; then
		echo -e "export NEXUS_PYPI_URL=$NEXUS_PYPI_URL\nexport NEXUS_PYPI_USER=$NEXUS_PYPI_USER\nexport NEXUS_PYPI_PASSWORD='$NEXUS_PYPI_PASSWORD'" > /tmp/.env.nexus
		NEXUS_SECRET="--secret id=nexus,src=/tmp/.env.nexus"
	else
		NEXUS_SECRET=""
	fi

	echo "jo.sh is currently hard coded to to use the following secret values:"
	echo "  - github_token: Used to authenticate with GitHub, located at ~/.github_token.txt"
	echo "  - Environment variables: NEXUS_PYPI_URL, NEXUS_PYPI_USER, NEXUS_PYPI_PASSWORD"
	
	docker build -t $CONTAINER_NAME $GITHUB_TOKEN_SECRET $NEXUS_SECRET $NO_CACHE --platform linux/amd64 . -f-<<-EOF
	FROM python:$PYTHON_IMAGE
	RUN apt-get update && apt-get install -y curl $ADDITIONAL_APT_PACKAGES
	RUN --mount=type=secret,id=github_token,uid=1000  git config --global url."https://\$(cat /run/secrets/github_token):@github.com/".insteadOf "https://github.com/"
	
	##############################################INSTALL POETRY##############################################
	ENV POETRY_HOME="/opt/poetry" \
		POETRY_VIRTUALENVS_CREATE=false \
		POETRY_VIRTUALENVS_IN_PROJECT=false \
		POETRY_NO_INTERACTION=1
	ENV PATH="\$PATH:\$POETRY_HOME/bin"
	RUN curl -SL https://install.python-poetry.org | python -
	##############################################INSTALL POETRY##############################################

	$PRE_POETRY_INSTALL_DOCKERFILE_COMMANDS

	RUN pip install --upgrade pip setuptools wheel
	$POETRY_FILES
	$POETRY_INSTALL
	ENTRYPOINT [ "bash" ]
	EOF
elif [ "$1" = "install" ]; then
	INSTALL_PATH=/usr/local/bin/jo.sh
	INSTALL_PATH2=/usr/local/bin/josh
	if [ "$0" != $INSTALL_PATH ]; then
		cp $0 $INSTALL_PATH
		ln -sf $INSTALL_PATH $INSTALL_PATH2
		chmod a+rx $INSTALL_PATH
	else
		echo "Cannot install this script to $INSTALL_PATH because this is already $INSTALL_PATH"
	fi
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
	echo "  build: Build the container"
	echo "    --poetry-install: Install the dependencies in the pyproject.toml file into the image"
	echo "    --no-cache: Do not use cache when building the image"
	echo "  install: Install this script to /usr/local/bin/josh (may require sudo)"
	echo "  help: Show this help message"
# if not empty, unrecognized 
elif [ -n "$1" ]; then
	echo "Unrecognized command: $1"
	echo "Use '$0 help' for more information"
else
	echo Launching a stateless interactive shell with Python and Poetry installed. Python version: $PYTHON_IMAGE
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