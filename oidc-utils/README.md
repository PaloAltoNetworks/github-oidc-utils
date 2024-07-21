# OIDC utils
<img width="777" alt="image" src="https://github.com/user-attachments/assets/e1a91191-6ea8-42ef-8521-b9df14a3904a">

A wrapper around [GitHub's OIDC API](https://docs.github.com/en/rest/actions/oidc?apiVersion=2022-11-28) that also:

1/ Inspects the `sub` claim formats for both the organization or the repository

2/ Allows modification of the `sub` for both the organization or the repository 


## Usage
```bash
./oidc-utils.sh <MODE> <ORG> <REPO - optional>
```

The possible modes are:

1. `-h` | `--help` | `help`

2. `update`

3. `inspect`

see below for more details


### `-h` | `--help` | `help`

Prints the following message
```bash
[ ! ] Update or inspect the OIDC configuration for an organization or a repository
[ ! ] Make sure the TOKEN (== github token with admin perms) environment variable is set
[ ! ] Usage: /opt/oidc-utils.sh [inspect|update|-h] org-name repo-name<optional>
```

### `inspect`

Inspects the OIDC configuration for the organization or the repository (if provided)
```
./oidc-utils.sh inspect my-org my-repo
```
This output may look something like this:

<img width="844" alt="image" src="https://github.com/user-attachments/assets/972c97c2-6adb-45f5-9005-454318d2cf73">

### `update`

Updates the OIDC configuration for the organization or the repository (if provided)
```
./oidc-utils.sh update my-org my-repo
```
This may look something like this:

<img width="755" alt="image" src="https://github.com/user-attachments/assets/d53fdafa-e4ce-4325-a73d-37a0ffaefee1">



## Installation
### Preferred way - Docker that I built for you 🐳
Simply pull and run the image with the required environment variable (the github token)

```bash
TOKEN=ghp_...
docker run -it -e TOKEN=$TOKEN ghcr.io/cider-research/oidc-utils:latest <MODE> <ORG> <REPO>
```

### I wanna build my own docker - Clone, build and run a container
1/ Clone the repo

2/ `cd` into `oidc-utils` and run `./build-docker.sh`

3/ Once done, run with:
`docker run -it -e TOKEN=ghp_... oidc-utils <MODE> <ORG> <REPO>`

### Worst way - clone and run locally
> Trying to push my agenda of everything in a container; Stop running OS stuff locally ⚠️

The script is suitable for Alpine so it should be compatible with most Nix-based systems.

**Prerequisites**: `jq`, `curl`

Once you've got the prerequisites, run the script like `./oidc-utils.sh <MODE> <ORG> <REPO>`
