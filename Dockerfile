# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

ARG FROM_PYTHON_BASE=vexxhost/docker-python-base
ARG FROM_OPENSTACK_VENV_BUILDER=vexxhost/openstack-venv-builder


FROM ${FROM_OPENSTACK_VENV_BUILDER} AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.4.0
EOF

FROM ${FROM_PYTHON_BASE}
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
