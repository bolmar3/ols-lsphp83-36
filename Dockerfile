# syntax=docker/dockerfile:1
#
# OpenLiteSpeed + lsphp83 rebuilt from upstream PHP source.
#
# Takes the official litespeedtech/openlitespeed:<ver>-lsphp83 image and
# replaces its PHP 8.3 build in place (/usr/local/lsws/lsphp83) with a
# fresh compile of PHP_VERSION, reusing the packaged build's exact
# ./configure options so paths, php.ini and extension dirs stay identical.
#
#   docker buildx build -t my/openlitespeed:1.9.3-lsphp83-8.3.36 .
#
# Patch releases keep the same extension API (8.3 = 20230831), so PECL
# extensions shipped in the base image (imagick, redis, memcached) keep
# working; bundled extensions are rebuilt from the new source.

ARG BASE_IMAGE=litespeedtech/openlitespeed:1.9.3-lsphp83
ARG PHP_VERSION=8.3.36
# sha256 of php-${PHP_VERSION}.tar.xz from https://www.php.net/releases/
ARG PHP_SHA256=dd54693aa334c5c4d72e9aee96b082c2473750a18a6c1d105789c93a3b1692fd
ARG LSPHP_DIR=/usr/local/lsws/lsphp83

FROM ${BASE_IMAGE} AS builder

ARG PHP_VERSION
ARG PHP_SHA256
ARG LSPHP_DIR
# configure options to drop (extended regex), e.g. when a -dev library no
# longer exists on the base distro. Dropped extensions keep the base
# image's 8.3.x build of that .so.
ARG CONFIGURE_EXCLUDE='^--with-(imap|imap-ssl|kerberos)(=|$)'

# Headers for everything a distro PHP build typically enables. Names that
# don't exist on this Ubuntu release are skipped rather than failing.
RUN <<'EOF'
set -eu
apt-get update
pkgs="build-essential pkg-config autoconf bison re2c xz-utils file
  libxml2-dev libssl-dev libsqlite3-dev zlib1g-dev libbz2-dev
  libcurl4-openssl-dev libonig-dev libzip-dev libpcre2-dev libexpat1-dev
  libpng-dev libjpeg-dev libwebp-dev libavif-dev libfreetype-dev libxpm-dev libgd-dev
  libicu-dev libxslt1-dev libsodium-dev libargon2-dev libgmp-dev
  libldap-dev libsasl2-dev libkrb5-dev libreadline-dev libedit-dev
  libtidy-dev libsnmp-dev libpq-dev libenchant-2-dev libpspell-dev libffi-dev
  unixodbc-dev freetds-dev libgdbm-dev libqdbm-dev liblmdb-dev libdb-dev
  libsystemd-dev libc-client2007e-dev"
avail=""
for p in $pkgs; do
    if apt-cache show "$p" >/dev/null 2>&1; then avail="$avail $p"; else echo "skip: $p"; fi
done
apt-get install -y --no-install-recommends $avail
EOF

WORKDIR /usr/src
RUN <<'EOF'
set -eu
curl -fsSL -o php.tar.xz "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz"
echo "${PHP_SHA256}  php.tar.xz" | sha256sum -c -
tar xJf php.tar.xz
EOF

WORKDIR /usr/src/php-${PHP_VERSION}
RUN <<'EOF'
#!/bin/bash
set -euo pipefail
"$LSPHP_DIR/bin/php" -v

# Recover the packaged build's configure line: './configure' 'opt1' 'opt2' ...
cfg=$("$LSPHP_DIR/bin/php" -i | sed -n "s/^Configure Command => *'[^']*configure' *//p")
[ -n "$cfg" ] || { echo "could not read Configure Command" >&2; exit 1; }
eval "orig=($cfg)"

opts=()
for opt in "${orig[@]}"; do
    if [[ $opt =~ $CONFIGURE_EXCLUDE ]]; then
        echo "dropping: $opt"
    else
        opts+=("$opt")
    fi
done
opts+=(--enable-litespeed)
printf 'configure:'; printf ' %q' "${opts[@]}"; echo

./configure "${opts[@]}"
make -j"$(nproc)"
sapi/cli/php -v

# Binaries (cli, lsphp, cgi) and shared extensions only; leaves php.ini,
# conf.d and PEAR from the base image untouched.
make INSTALL_ROOT=/out install-sapi install-binaries install-modules
EOF


FROM ${BASE_IMAGE}

ARG PHP_VERSION
ARG LSPHP_DIR

COPY --from=builder /out${LSPHP_DIR}/ ${LSPHP_DIR}/

RUN <<'EOF'
set -eu
"$LSPHP_DIR/bin/php" -v | grep -q "PHP $PHP_VERSION "
"$LSPHP_DIR/bin/lsphp" -v | grep -q "PHP $PHP_VERSION "
# fail if any extension in the ini no longer loads
if "$LSPHP_DIR/bin/php" -m 2>&1 | grep -Ei 'warning|error'; then exit 1; fi
"$LSPHP_DIR/bin/php" -m
EOF
