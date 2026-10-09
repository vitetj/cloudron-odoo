# Run via `odoo shell` on every start: syncs Cloudron addon credentials into Odoo through the ORM.
import os

e = os.environ
domain = e.get("CLOUDRON_APP_DOMAIN", "")
ICP = env["ir.config_parameter"].sudo()


def set_param(key, value):
    # Odoo 20 replaced set_param() with typed setters
    if hasattr(ICP, "set_str"):
        ICP.set_bool(key, value) if isinstance(value, bool) else ICP.set_str(key, value)
    else:
        ICP.set_param(key, value)


set_param("web.base.url", e.get("CLOUDRON_APP_ORIGIN", "https://" + domain))
set_param("web.base.url.freeze", True)
set_param("auth_signup.invitation_scope", "b2b")

# Outgoing mail (sendmail addon)
Smtp = env["ir.mail_server"].sudo().with_context(active_test=False)
smtp = Smtp.search([("name", "=", "Cloudron SMTP")], limit=1)
if e.get("CLOUDRON_MAIL_SMTP_SERVER"):
    vals = {
        "name": "Cloudron SMTP",
        "smtp_host": e["CLOUDRON_MAIL_SMTP_SERVER"],
        "smtp_port": int(e["CLOUDRON_MAIL_SMTP_PORT"]),
        "smtp_authentication": "login",
        "smtp_user": e["CLOUDRON_MAIL_SMTP_USERNAME"],
        "smtp_pass": e["CLOUDRON_MAIL_SMTP_PASSWORD"],
        "smtp_encryption": "none",
        "sequence": 1,
        "active": True,
    }
    smtp.write(vals) if smtp else Smtp.create(vals)
    mail_domain = e.get("CLOUDRON_MAIL_DOMAIN") or domain
    if "mail.alias.domain" in env:
        Alias = env["mail.alias.domain"].sudo()
        if not Alias.search([("name", "=", mail_domain)], limit=1):
            Alias.create({"name": mail_domain})
    else:
        set_param("mail.catchall.domain", mail_domain)
    if e.get("CLOUDRON_MAIL_FROM"):
        set_param("mail.default.from", e["CLOUDRON_MAIL_FROM"].split("@")[0])
elif smtp:
    smtp.active = False

# Incoming mail (recvmail addon)
if "fetchmail.server" in env:
    Fetch = env["fetchmail.server"].sudo().with_context(active_test=False)
    fetch = Fetch.search([("name", "=", "Cloudron IMAP")], limit=1)
    if e.get("CLOUDRON_MAIL_IMAP_SERVER"):
        vals = {
            "name": "Cloudron IMAP",
            "server_type": "imap",
            "server": e["CLOUDRON_MAIL_IMAP_SERVER"],
            "port": int(e["CLOUDRON_MAIL_IMAP_PORT"]),
            "is_ssl": False,
            "user": e["CLOUDRON_MAIL_IMAP_USERNAME"],
            "password": e["CLOUDRON_MAIL_IMAP_PASSWORD"],
            "active": True,
        }
        fetch.write(vals) if fetch else Fetch.create(vals)
    elif fetch:
        fetch.active = False

# LDAP login (ldap addon)
if "res.company.ldap" in env:
    Ldap = env["res.company.ldap"].sudo()
    company = env.ref("base.main_company")
    ldap = Ldap.search([("company", "=", company.id)], limit=1)
    if e.get("CLOUDRON_LDAP_SERVER"):
        vals = {
            "company": company.id,
            "sequence": 10,
            "ldap_server": e["CLOUDRON_LDAP_SERVER"],
            "ldap_server_port": int(e["CLOUDRON_LDAP_PORT"]),
            "ldap_binddn": e["CLOUDRON_LDAP_BIND_DN"],
            "ldap_password": e["CLOUDRON_LDAP_BIND_PASSWORD"],
            "ldap_base": e["CLOUDRON_LDAP_USERS_BASE_DN"],
            "ldap_filter": "(&(objectclass=user)(|(username=%s)(mail=%s)))",
            "ldap_tls": False,
            "create_user": True,
        }
        ldap.write(vals) if ldap else Ldap.create(vals)
    elif ldap:
        ldap.unlink()

env.cr.commit()
