# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ghcr.io/vexxhost/openstack-venv-builder:2025.2@sha256:5aeecef69784a92e03a48c7396dee7dc3945451db9292f216caa7756cdae8612 AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.4.0
EOF

FROM ghcr.io/vexxhost/python-base:2025.2@sha256:116f29c8dd72f595a0a1b0189842d1f492bd9578291a7dfdcdde2a22d5777f8a
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
ARG MOD_AUTH_OPENIDC_VERSION=2.4.18.1
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
