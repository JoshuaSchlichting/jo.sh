
# Josh's Own SHell
## A tool for managing Python environments with Docker.

Use `jo.sh` in lieu of `virtualenv`, `venv,` `pyenv`, or any of the others. Simple build your image with `./jo.sh build` and run it with `./jo.sh`. This leaves you without any more [messy local Python installations on your machine](https://xkcd.com/1987/).


```
Usage: ./jo.sh [COMMAND] [OPTIONS]
Commands:
  build: Build the container
    --poetry-install: Install the dependencies in the pyproject.toml file into the image
    --no-cache: Do not use cache when building the image
  install: Install this script to /usr/local/bin/josh (may require sudo)
  help: Show this help message
```