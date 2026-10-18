# CI Server Checks Buildkite Plugin

Checks DNS resolution and the HTTPS certificate for a domain before the Buildkite step command runs. It uses standard system tools and does not depend on the separate A1 scripts.

## Requirements

The Buildkite agent environment must provide:

- Bash
- `getent` (usually supplied by glibc)
- OpenSSL
- `timeout` (usually supplied by coreutils)
- Network access to resolve the domain and connect to TCP port 443

The plugin checks that the hostname resolves, retrieves the HTTPS certificate using SNI, validates the hostname and certificate chain using the local OpenSSL trust store, and fails if the certificate is expired or expires within the configured threshold.

This checks DNS resolution and HTTPS certificate validity; it does not verify application-specific DNS record policy, HTTP response codes, or mail records.

## Usage

```yaml
steps:
  - label: "Check DNS and HTTPS certificate"
    command: ./scripts/run-tests.sh
    plugins:
      - iserver-support/ci-server-checks-plugin#v1.0.0:
          domain: example.com
          alert-days: 14
```

Replace `example.com` with a hostname you control. The check runs before the step's `command`; if it fails, the command does not run. Pin the plugin to a reviewed release tag or commit.

## Configuration

| Option | Required | Default | Description |
|---|---|---|---|
| `domain` | Yes | — | Hostname to resolve and check over HTTPS on port 443. |
| `alert-days` | No | `10` | Positive integer; fail if the certificate expires within this many days. |

## Testing

Run the test suite with Docker:

```sh
docker compose run --rm tests
```

The tests stub DNS and OpenSSL commands and do not contact public services. Before production use, test against a staging hostname and confirm both success and failure cases.

## Related resource

For related cloud server administration and management services, see [iServerSupport Cloud Server Management](https://iserversupport.com/cloud-server-management/).
