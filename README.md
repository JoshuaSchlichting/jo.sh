
# Josh's Own SHell
## A tool for managing Python environments with Docker.
`jo.sh` is a wrapper around Docker that allows you to easily build and run Python projects in a containerized environment.
Use `jo.sh` in lieu of `virtualenv`, `venv,` `pyenv`, or any of the others; *Python itself is not required*. Simply build your image with `./jo.sh build` and run it with `./jo.sh`. 


```
Usage: ./jo.sh [COMMAND] [OPTIONS]
Commands:
  run: Launch a stateless interactive shell with Python and Poetry installed
    --detach, -d: Run the container in the background
  stop: Stop the container if running
  build: Build the container
    --poetry-install: Install the dependencies in the pyproject.toml file into the image
    --no-cache: Do not use cached layers of user specific content (poetry packages, Dockerfile commands from /Users/josh/.config/josh/dockerfile_commands)
    --no-cache-all: Do not use cache at all when building the image, this includes the base image and all layers
    --tagv [TAG VERSION]: Specify a Python docker image version (default: pyproject.toml's spec or 3.12). Example: --tagv 3.9
  clean: Stop and remove the container and image
  install: Install this script to /usr/local/bin/jo.sh and create a josh symlink (may require sudo)
  uninstall: Uninstall this script from /usr/local/bin/jo.sh (may require sudo)
  history: Show the history of the container image (alias for 'docker history --format {{.CreatedBy}} $(pwd) --no-trunc)'
  help: Show this help message
Options:
  --version, -v: Show the version of jo.sh
```

### Installation
`curl https://raw.githubusercontent.com/JoshuaSchlichting/jo.sh/master/jo.sh --output jo.sh && chmod +x jo.sh && ./jo.sh install`
> Note: You may need to modify the above command to use `sudo` for the `jo.sh install` if you do not have permission to write to `/usr/local/bin`.


### Add custom `Dockerfile` commands
Add to `~/.config/josh/docker_commands` to add custom `Dockerfile` commands that will run immediately after Poetry is installed and any GitHub secret token is injected, while running *before* the `poetry install` command is issued, should you decided to run `jo.sh build --poetry-install`. This is useful for adding custom dependencies or setting up your environment in a specific way.

### Poetry
For now, `jo.sh` comes with Poetry as a default dependency. I'm considering only installing it automatically if a `pyproject.toml` file is present in the project directory. If you have any thoughts on this, I'd love to hear feedback.
>#### *What is Poetry?*
>Poetry is a tool for dependency management and packaging in Python. It allows you to declare the libraries your project depends on and it will manage (install/update) them for you. [Read more here.](https://python-poetry.org/docs/)