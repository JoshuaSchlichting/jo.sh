
# Josh's Own SHell
## A tool for managing Python environments with Docker.

Use `jo.sh` in lieu of `virtualenv`, `venv,` `pyenv`, or any of the others; *Python itself is not required*. Simply build your image with `./jo.sh build` and run it with `./jo.sh`. This leaves you without any more [messy local Python installations on your machine](https://xkcd.com/1987/).


```
Usage: ./jo.sh [COMMAND] [OPTIONS]
Commands:
  build: Build the container
    --poetry-install: Install the dependencies in the pyproject.toml file into the image
    --no-cache: Do not use cache when building the image
    --no-cache-all: Do not use cache at all when building the image
    --image [IMAGE]: Use a different Python image (default: 3.10-slim-buster)
  clean: Stop and remove the container and image
  install: Install this script to /usr/local/bin/jo.sh and create a josh symlink (may require sudo)
  uninstall: Uninstall this script from /usr/local/bin/jo.sh (may require sudo)
  help: Show this help message
```

### Installation
`curl https://raw.githubusercontent.com/JoshuaSchlichting/jo.sh/master/jo.sh --output jo.sh && chmod +x jo.sh && ./jo.sh install`

### Add custom `Dockerfile` commands
Add to `~/.config/josh/docker_commands` to add custom `Dockerfile` commands that will run immediately after Poetry is installed and any GitHub secret token is injected, while running *before* the `poetry install` command is issued, should you decided to run `jo.sh build --poetry-install`. This is useful for adding custom dependencies or setting up your environment in a specific way.
