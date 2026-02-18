# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ghcr.io/vexxhost/openstack-venv-builder:2023.2@sha256:ab041e2d489a0ee73b056a4c57a6018a737543121ff3026f581cbfb22877e882 AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.5.0
EOF

FROM ghcr.io/vexxhost/python-base:2023.2@sha256:4ae056e7aba5caabbdd9cd31dd60c5322a0150fcc28fba49718e8fa36f3283be
RUN \
    groupadd -g 42424 keystone && \
    useradd -u 42424 -g 42424 -M -d /var/lib/keystone -s /usr/sbin/nologin -c "Keystone User" keystone && \
    mkdir -p /etc/keystone /var/log/keystone /var/lib/keystone /var/cache/keystone && \
    chown -Rv keystone:keystone /etc/keystone /var/log/keystone /var/lib/keystone /var/cache/keystone
RUN <<EOF bash -xe
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    apache2 libapache2-mod-wsgi-py3
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
ARG MOD_AUTH_OPENIDC_VERSION=2.4.12.1
ARG TARGETARCH
RUN <<EOF bash -xe
# TODO(mnaser): mod_auth_openidc does not have aarch64 builds
if [ "${TARGETARCH}" = "arm64" ]; then
    exit 0
fi

apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    curl
curl -LO https://github.com/OpenIDC/mod_auth_openidc/releases/download/v${MOD_AUTH_OPENIDC_VERSION}/libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
apt-get install -y --no-install-recommends ./libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
a2enmod auth_openidc
apt-get purge -y --auto-remove curl
apt-get clean
rm -rfv /var/lib/apt/lists/* libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
EOF
COPY --from=build --link /var/lib/openstack /var/lib/openstack
