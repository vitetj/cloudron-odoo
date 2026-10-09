## What

Run [Odoo 20](https://www.odoo.com/) on [Cloudron](https://cloudron.io). Fork of
[njsubedi/cloudron-odoo](https://github.com/njsubedi/cloudron-odoo), upgraded from Odoo 15 to Odoo 20.

- Base image `cloudron/base:5.0.0` (Ubuntu 24.04), Odoo installed from the official nightly `.deb`
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

```bash
./dev-scripts/fetch-debs.sh          # .debs go to vendor/ (SHA1 checked during the build)
cloudron build --repository docker.io/vitetj/odoo
cloudron versions add                # appends the build to CloudronVersions.json
git commit -am "Release x.y.z" && git push
```

To move to a newer Odoo nightly, update `ODOO_RELEASE` and the SHA1 in the `Dockerfile` and the URL in
`dev-scripts/fetch-debs.sh`, then bump `version` in `CloudronManifest.json`. On start, a new release triggers
`odoo -u all` automatically.

## Third-party Intellectual Properties

All third-party product names, company names, and their logos belong to their respective owners, and may be their
trademarks or registered trademarks.
