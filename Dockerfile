# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ghcr.io/vexxhost/openstack-venv-builder:2023.2@sha256:77839c08a283843b3c01439093a079e544cbaa029f9eef8760744a57fc8f3840 AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.5.0
EOF

FROM ghcr.io/vexxhost/python-base:2023.2@sha256:5d7468685854b39638cf96fb0513ca28532cdfedb9801770d77c1e8c0af896e0
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
