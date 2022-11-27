# woodpecker-git-setup

A [Woodpecker CI](https://woodpecker-ci.org) (and [Dorne CI](https://www.drone.io))
plugin to configure the cloned git repository to enable interactions in subsequent
steps.

Woodpecker provides a clone step for cloning the repository into the workspace
but does not expose username and password for interacting with the git repository
in subsequent steps.

If your pipeline needs to interact with the git repository (be it a simple
`git fetch`, a version upgrade of your project e.g. using `npm version` or a
complete gitflow release process) you have to provide a means to do so.

Ths plugin configures the current workspace to allow interactions in all subsequent
steps by:

- setting `user.name` and `user.email` in the git config
- storing a ssh key used to authenticate against the git srver inside the .git
  directory
- configering the ssh command to use the key and ignore the servers host keys
- setting or converting the repository url to a ssh-url

## Usage

### Preparation

1. Create a user in the forge who has the required permissions on the repo
2. Create a ssh key for that user and add the public key to the forge
3. Add the private key of this user to woodpecker (either global, repo or
   pipeline level) using the e.g. name WOODPECKER_SSH_KEY

### Pipeline configuration

Basic usage example: Configure remote `origin`

```yaml
pipeline:
  - name: Setup git
    image: smainz/woodpecker-git-setup
    settings:
      ssh_key:
        from_secret: WOODPECKER_SSH_KEY
      user_name: Woodpecker-CI
      user_email: woodpecker@example.com

  - name: Test it worked
    image: alpine
    commands:
      - apk add --no-cache openssh-client ca-certificates git
      - git fetch
      - touch test.txt
      - date >> test.txt
      - git add test.txt
      - git commit -m "Touch form Woodpecker [ci skip]"
```

Advanced example: Add additional remote `upstream`

```yaml
pipeline:
  - name: Setup git
    image: smainz/woodpecker-git-setup
    settings:
      ssh_key:
        from_secret: WOODPECKER_SSH_KEY
      user_name: Woodpecker-CI
      user_email: woodpecker@example.com
      remote: upstream
      remote_url: git@some.host/owner/repo

  - name: Test it worked
    image: alpine
    commands:
      - apk add --no-cache openssh-client ca-certificates git
      - git fetch upstream master
      - git switch -c new_branch
      - date >> test.txt
      - git add test.txt
      - git commit -m "Date form Woodpecker [ci skip]"
      - git push --set-upstream upstream new_branch
```

### Settings

| Settings Name | Default       | Description                                                                      |
|---------------|---------------|----------------------------------------------------------------------------------|
| remote        | origin        | The remote to configure                                                          |
| remote_url    | *none*        | The remote url to configure. Leave empty to convert existing http-url to ssh-url |
| ssh_key       | *none*        | The ssh private key to use to authenticate against the git repository            |
| user_email    | *none*        | The email address to configure `git config --local user.email "${email}"`        |
| user_name     | Woodpecker-CI | The user name to configure `git config --local user.name "${username}"`          |

## Development

The plugin abuses the `.git` directory in the workspace to persist the ssh key
between different steps. The reason for this is that `.git` is ignored by git
and you do not get untracked files you would otherwise have to care about.
Usually one would place a proper config in ~/.ssh/config, but this does not
persist between steps.

### Build

```bash
docker build -t smainz/woodpecker-git-setup .
docker push smainz/woodpecker-git-setup
```

### Run

Run on the shell (switch origin to ssh):

```bash
PLUGIN_USER_NAME="Woody Woodpecker" \
PLUGIN_USER_EMAIL="woodpecker@example.com" \
PLUGIN_SSH_KEY="$(cat ~/.ssh/id_rsa)" \
./docker-entrypoint.sh
```

Run in docker:

```bash
docker run --rm -it \
  --user="$(id -u):$(id -g)" \
  -e PLUGIN_USER_NAME="Woody Woodpecker" \
  -e PLUGIN_USER_EMAIL="woodpecker@example.com" \
  -e PLUGIN_REMOTE="upstream" \
  -e PLUGIN_SSH_KEY="$(cat ~/.ssh/id_rsa)" \
  -v $(pwd):/woodpecker/src \
  smainz/woodpecker-setup-git
```

### Future enhancement ideas

- Scan the git hosts host keys, store them locally and confgure
  `ssh -o "UserKnownHostsFile my_temp_known_host" host.example.com`
- Allow calling the plugin multiple times in a pipeline to set up multiple
  remotes possibly with different ssh keys. Can be achieved by setting up a
  proper ssh config file and use that one using the `ssh -F config_file>`
