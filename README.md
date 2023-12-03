# This Repo
This repo used to be the home of setup scripts for vagrant when we were primarily relying on vagrant + linux VMs for our dev envs. The historical reason for switching to that environment was primarily because docker for mac _sucked_ and was terribly slow.

With the rise of [Orbstack](https://orbstack.dev) we can return to a more familiar environment utilizing the host machine directly to run docker containers.

# Big Cartel Development Environment

This repo now simply houses a shell script which installs base dependencies in an automated fashion and sets up the two core repos for you:
[Dotmatrix](https://github.com/bigcartel/dotmatrix) (our tooling) and
[compose-dev](https://github.com/bigcartel/compose-dev) (our apps) in Docker for developing on macOS.

# Bootstrapping

You can easily run the latest setup script without pulling down this repo:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bigcartel/dev/HEAD/setup.sh)"
```