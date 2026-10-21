## What

Run [Odoo 20](https://www.odoo.com/) on [Cloudron](https://cloudron.io). Fork of
[njsubedi/cloudron-odoo](https://github.com/njsubedi/cloudron-odoo), upgraded from Odoo 15 to Odoo 20.

- Base image `cloudron/base:5.1.0` (Ubuntu 24.04, no PHP), Odoo installed from the official nightly `.deb`
- PostgreSQL, sendmail, recvmail and LDAP addons wired in through the Odoo ORM (`configure.py`) on every start
- Live chat / bus served on `/websocket`
- Custom modules: drop them in `/app/data/extra-addons`, then restart the app

## Install (Community app)

In the Cloudron dashboard: **App Store → Community apps → Add**, then paste:

```
https://raw.githubusercontent.com/vitetj/cloudron-odoo/main/CloudronVersions.json
```

Default login is `admin` / `admin`: change it right after install.

## Build a new version

Needs the `cloudron` CLI 9.x (`npm install -g cloudron`), Docker and a Docker Hub login (`docker login`).
The image targets `linux/amd64`, so build with `buildx` on Apple Silicon.

```bash
./dev-scripts/fetch-debs.sh                      # .debs go to vendor/ (SHA1 checked during the build)
version=$(python3 -c 'import json;print(json.load(open("CloudronManifest.json"))["version"])')
docker buildx build --platform linux/amd64 --push -t docker.io/vitetj/odoo:$version .
cloudron versions add --image docker.io/vitetj/odoo:$version   # appends the build to CloudronVersions.json
git commit -am "Release $version" && git push
```

With the Container Registry app installed on your Cloudron, `cloudron builder build --repository vitetj/odoo`
followed by `cloudron versions add --last-build` builds remotely instead of locally.

Cloudron's "Check for updates" only sees versions listed in `CloudronVersions.json` on `main`: bumping
`version` in `CloudronManifest.json` is not enough until `cloudron versions add` has been run and pushed.

## Third-party Intellectual Properties

All third-party product names, company names, and their logos belong to their respective owners, and may be their
trademarks or registered trademarks.
