# ols-lsphp83

The official [`litespeedtech/openlitespeed`](https://hub.docker.com/r/litespeedtech/openlitespeed)
lsphp83 image, with PHP 8.3 rebuilt from upstream source so security
releases can ship before LiteSpeed's packaged `lsphp83` catches up.

The [Dockerfile](Dockerfile) compiles PHP using the packaged build's exact
`./configure` options and replaces `/usr/local/lsws/lsphp83` in place.
`php.ini`, `conf.d`, vhost config and PECL extensions (imagick, redis,
memcached) from the base image are kept.

## Use

```bash
docker pull ghcr.io/bolmar3/ols-lsphp83:latest
docker run -d -p 80:80 -p 443:443 -p 7080:7080 ghcr.io/bolmar3/ols-lsphp83:latest
```

Tags:

| Tag                   | Example                  |
| --------------------- | ------------------------ |
| `<ols>-lsphp83-<php>` | `1.9.3-lsphp83-8.3.36`   |
| `lsphp83-<php>`       | `lsphp83-8.3.36`         |
| `lsphp83`, `latest`   | newest build from `main` |
| `<semver>`            | from a `v*` git tag      |
| `sha-<commit>`        | every build              |

Images are multi-arch (`linux/amd64`, `linux/arm64`).

## Updating PHP

1. Take the version and `.tar.xz` sha256 from <https://www.php.net/releases/>:
   ```bash
   curl -s 'https://www.php.net/releases/index.php?json&version=8.3'
   ```
2. Update `ARG PHP_VERSION` and `ARG PHP_SHA256` at the top of the `Dockerfile`.
3. Open a PR. CI builds both architectures and runs the smoke test;
   merging to `main` publishes.

To move to a newer OpenLiteSpeed, change `ARG BASE_IMAGE`.

## Build locally

```bash
docker buildx build -t ols-lsphp83:test --load .
./test.sh ols-lsphp83:test 8.3.36
```

## CI

`.github/workflows/build.yml`:

- **PRs:** build each platform on a native runner and smoke-test; nothing is pushed.
- **`main`, `v*` tags, weekly schedule, manual:** additionally push per-platform
  images by digest to GHCR and merge them into one multi-arch manifest.

Publishing uses the workflow's `GITHUB_TOKEN`; no secrets are needed.

## Build args

| Arg                 | Default                                     |                                                                         |
| ------------------- | ------------------------------------------- | ----------------------------------------------------------------------- |
| `BASE_IMAGE`        | `litespeedtech/openlitespeed:1.9.3-lsphp83` |                                                                         |
| `PHP_VERSION`       | `8.3.36`                                    |                                                                         |
| `PHP_SHA256`        | checksum of `php-8.3.36.tar.xz`             |                                                                         |
| `CONFIGURE_EXCLUDE` | `^--with-(imap\|imap-ssl\|kerberos)(=\|$)`  | configure options to drop; those extensions keep the base image's build |
