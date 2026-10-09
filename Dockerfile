FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c
# Reference: https://github.com/odoo/docker/blob/master/20.0/Dockerfile

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

RUN mkdir -p /app/code /app/pkg /app/data
WORKDIR /app/code

# The .debs are fetched on the host into vendor/ (see dev-scripts/fetch-debs.sh) because
# the build network intercepts TLS; their SHA1 is still checked against upstream values.
#   https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
#   https://nightly.odoo.com/20.0/nightly/deb/odoo_20.0.20260926_all.deb
ARG ODOO_VERSION=20.0
ARG ODOO_RELEASE=20260926
COPY vendor/wkhtmltox.deb vendor/odoo.deb /tmp/

# wkhtmltopdf (patched Qt build used by the official Odoo image)
RUN echo '967390a759707337b46d1c02452e2bb6b2dc6d59 /tmp/wkhtmltox.deb' | sha1sum -c - && \
    echo '7cb4a582ebe275a4f9c22eae24ce2bcb7fa27040 /tmp/odoo.deb' | sha1sum -c - && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/wkhtmltox.deb fonts-noto-cjk node-less python3-ldap && \
    apt-get install -y --no-install-recommends /tmp/odoo.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deb && \
    test -d /usr/lib/python3/dist-packages/odoo/addons/base && \
    echo "${ODOO_VERSION}.${ODOO_RELEASE}" > /app/pkg/ODOO_RELEASE

# Map Cloudron's 'displayname' LDAP attribute to the Odoo user name instead of 'cn'
RUN f=/usr/lib/python3/dist-packages/odoo/addons/auth_ldap/models/res_company_ldap.py && \
    if grep -q "ldap_entry\[1\]\['cn'\]" "$f"; then \
        sed -i "s/ldap_entry\[1\]\['cn'\]/(ldap_entry[1].get('displayname') or ldap_entry[1]['cn'])/" "$f"; \
    fi

RUN rm -rf /var/log/nginx && mkdir -p /run/nginx && ln -s /run/nginx /var/log/nginx

COPY start.sh configure.py odoo.conf.sample nginx.conf /app/pkg/
RUN chmod +x /app/pkg/start.sh

CMD [ "/app/pkg/start.sh" ]
