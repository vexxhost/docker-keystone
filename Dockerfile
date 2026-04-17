# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ghcr.io/vexxhost/openstack-venv-builder-debian:main@sha256:c73dcb6aa80144d44a00116779e233174ed3f3b6f520026cb3a81e84d6c1dd28 AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.5.0
EOF

FROM ghcr.io/vexxhost/python-base-debian:main@sha256:c10a59b249b17045161b94d62a398b6687055cb12ffd22ae414a6d68e92d4dc8
RUN \
  groupadd -g 42424 keystone && \
  useradd -u 42424 -g 42424 -M -d /var/lib/keystone -s /usr/sbin/nologin -c "Keystone User" keystone && \
  mkdir -p /etc/keystone /var/log/keystone /var/lib/keystone /var/cache/keystone && \
  chown -Rv keystone:keystone /etc/keystone /var/log/keystone /var/lib/keystone /var/cache/keystone
RUN <<EOF bash -xe
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    apache2 libapache2-mod-wsgi-py3 libapache2-mod-auth-openidc
apt-get clean
rm -rf /var/lib/apt/lists/*
a2enmod auth_openidc
EOF
COPY --from=build --link /var/lib/openstack /var/lib/openstack
