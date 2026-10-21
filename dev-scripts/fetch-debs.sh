#!/bin/bash
# Download the .debs installed by the Dockerfile into vendor/ (SHA1s are checked at build time)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p vendor
curl -fsSL -o vendor/wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
curl -fsSL -o vendor/odoo.deb https://nightly.odoo.com/20.0/nightly/deb/odoo_20.0.20260926_all.deb