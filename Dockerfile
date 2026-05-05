# SPDX-FileCopyrightText: © 2026 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ghcr.io/vexxhost/openstack-venv-builder:main@sha256:757a611b5f2d57ffe4493a48d26bfd095a7a62098fae07d19a7af7d04bed48d3 AS build
RUN --mount=type=bind,from=keystone,source=/,target=/src/keystone,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/keystone[ldap] \
        keystone-keycloak-backend==0.5.0
EOF

FROM ghcr.io/vexxhost/python-base:main@sha256:50e5971a288dffb24607884ff315ea8595045c15b743be70244a0b609ca7f3c6
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
# NOTE: Always use compatible version of liboauth2 and mod_oauth2,
#       otherwise mod_oauth2 will fail to load due to missing shared library.
ARG LIBOAUTH2_VERSION=2.1.1
ARG MOD_OAUTH2_VERSION=4.1.0
ARG TARGETARCH
RUN <<EOF bash -xe
# TODO(mnaser): mod_auth_openidc and mod_oauth2 does not have aarch64 builds
if [ "${TARGETARCH}" = "arm64" ]; then
    exit 0
fi

apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    curl
curl -LO https://github.com/OpenIDC/mod_auth_openidc/releases/download/v${MOD_AUTH_OPENIDC_VERSION}/libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
curl -LO https://github.com/OpenIDC/liboauth2/releases/download/v${LIBOAUTH2_VERSION}/liboauth2_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
curl -LO https://github.com/OpenIDC/liboauth2/releases/download/v${LIBOAUTH2_VERSION}/liboauth2-apache_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
curl -LO https://github.com/OpenIDC/mod_oauth2/releases/download/v${MOD_OAUTH2_VERSION}/libapache2-mod-oauth2_${MOD_OAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
apt-get install -y --no-install-recommends \
    ./libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    ./liboauth2_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    ./liboauth2-apache_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    ./libapache2-mod-oauth2_${MOD_OAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
a2enmod auth_openidc oauth2
apt-get purge -y --auto-remove curl
apt-get clean
rm -rfv /var/lib/apt/lists/* \
    libapache2-mod-auth-openidc_${MOD_AUTH_OPENIDC_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    liboauth2_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    liboauth2-apache_${LIBOAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb \
    libapache2-mod-oauth2_${MOD_OAUTH2_VERSION}-1.$(lsb_release -sc)_${TARGETARCH}.deb
EOF
COPY --from=build --link /var/lib/openstack /var/lib/openstack
