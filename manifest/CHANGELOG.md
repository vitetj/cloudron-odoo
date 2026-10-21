[20.0.2]
* Security: move to cloudron/base 5.1.0, which no longer bundles PHP. Base 5.0.0 shipped PHP 8.3, affected by the critical unauthenticated RCEs CVE-2026-109618 / CVE-2026-109619 (CERT-EU 2026-018). Odoo never used it, and the build now fails if PHP reappears in the image.

[20.0.1]
* Fix first start on Cloudron: use the app database as db_system instead of 'postgres'

[20.0.0]
* Odoo 20.0 (nightly 20260926), cloudron/base 5.0.0 (Ubuntu 24.04)
* Mail and LDAP settings are synced through the Odoo ORM on every start
* Live chat / bus over /websocket

[15.0.0]
* First release of Odoo 15.0.
