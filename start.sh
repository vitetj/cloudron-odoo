#!/bin/bash
set -euo pipefail

export LANG="C.UTF-8"
export HOME=/app/data
CONF=/app/data/odoo.conf
ODOO="/usr/local/bin/gosu cloudron:cloudron /usr/bin/odoo"
BASE_ADDONS=/usr/lib/python3/dist-packages/odoo/addons

mkdir -p /app/data/extra-addons /app/data/odoo /run/nginx /run/odoo

[[ -f "$CONF" ]] || cp /app/pkg/odoo.conf.sample "$CONF"

echo "=> Writing [options] in $CONF"
set_opt() { crudini --set "$CONF" options "$1" "$2"; }

# Only add extra-addons when it holds modules, otherwise Odoo rejects the path
addons_path="$BASE_ADDONS"
if compgen -G "/app/data/extra-addons/*/__manifest__.py" >/dev/null; then
    addons_path="$addons_path,/app/data/extra-addons"
fi
set_opt addons_path "$addons_path"
set_opt data_dir /app/data/odoo

set_opt logfile ""
set_opt syslog False

set_opt proxy_mode True
set_opt http_interface 127.0.0.1
set_opt http_port 8069
set_opt gevent_port 8072

set_opt list_db False
set_opt dbfilter "^${CLOUDRON_POSTGRESQL_DATABASE}\$"
set_opt db_name "$CLOUDRON_POSTGRESQL_DATABASE"
set_opt db_host "$CLOUDRON_POSTGRESQL_HOST"
set_opt db_port "$CLOUDRON_POSTGRESQL_PORT"
set_opt db_user "$CLOUDRON_POSTGRESQL_USERNAME"
set_opt db_password "$CLOUDRON_POSTGRESQL_PASSWORD"
set_opt db_sslmode disable

if [[ -n "${CLOUDRON_MAIL_FROM:-}" ]]; then
    set_opt email_from "$CLOUDRON_MAIL_FROM"
fi

# Master password for the (disabled) database manager: random, generated once
if ! crudini --get "$CONF" options admin_passwd >/dev/null 2>&1; then
    set_opt admin_passwd "$(openssl rand -hex 24)"
fi

# Workers sized on the container memory limit (cgroup v2, then v1)
if [[ -f /sys/fs/cgroup/memory.max && "$(cat /sys/fs/cgroup/memory.max)" != "max" ]]; then
    memory_limit=$(cat /sys/fs/cgroup/memory.max)
elif [[ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
    memory_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
else
    memory_limit=2684354560
fi
workers=$(( memory_limit / 1024 / 1024 / 768 ))
workers=$(( workers > 8 ? 8 : workers ))
workers=$(( workers < 2 ? 2 : workers ))
set_opt workers "$workers"
set_opt max_cron_threads 1
set_opt limit_memory_soft $(( 640 * 1024 * 1024 ))
set_opt limit_memory_hard $(( 1024 * 1024 * 1024 ))
set_opt limit_time_cpu 600
set_opt limit_time_real 1200
echo "=> Memory limit ${memory_limit} bytes, ${workers} workers"

chown -R cloudron:cloudron /app/data /run/odoo

# First run: initialise the database
db_ready=$(PGPASSWORD="$CLOUDRON_POSTGRESQL_PASSWORD" psql -h "$CLOUDRON_POSTGRESQL_HOST" -p "$CLOUDRON_POSTGRESQL_PORT" \
    -U "$CLOUDRON_POSTGRESQL_USERNAME" -d "$CLOUDRON_POSTGRESQL_DATABASE" -tAc \
    "SELECT 1 FROM information_schema.tables WHERE table_name = 'ir_module_module'" || true)

modules="base,web,mail"
[[ -n "${CLOUDRON_LDAP_SERVER:-}" ]] && modules="$modules,auth_ldap"

release=$(cat /app/pkg/ODOO_RELEASE)
if [[ "$db_ready" != "1" ]]; then
    echo "=> First run, initialising database"
    $ODOO -c "$CONF" -i "$modules" --no-http --stop-after-init
    echo "$release" > /app/data/.odoo_release
elif [[ "$(cat /app/data/.odoo_release 2>/dev/null || true)" != "$release" ]]; then
    echo "=> Odoo release changed, updating modules"
    $ODOO -c "$CONF" -u all --no-http --stop-after-init
    echo "$release" > /app/data/.odoo_release
fi

echo "=> Applying Cloudron mail / LDAP settings"
$ODOO shell -c "$CONF" --no-http --log-level=warn < /app/pkg/configure.py || echo "=> WARNING: configure.py failed, continuing"

# nginx
cp /app/pkg/nginx.conf /run/nginx/nginx.conf
if [[ ! -f /app/data/nginx-custom-locations.conf ]]; then
    cat > /app/data/nginx-custom-locations.conf <<EOF
# Included inside the server { } block. "/" and "/websocket" are reserved for Odoo.
EOF
fi
rm -f /run/nginx.pid
echo "=> Starting nginx"
nginx -c /run/nginx/nginx.conf &

echo "=> Starting Odoo ${release}"
exec $ODOO -c "$CONF"
