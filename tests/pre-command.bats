load "$BATS_PLUGIN_PATH/load.bash"

setup() {
  TEST_BIN="$(mktemp -d)"
  export PATH="$TEST_BIN:$PATH"
  export BUILDKITE_PLUGIN_CI_SERVER_CHECKS_DOMAIN="example.com"
  export BUILDKITE_PLUGIN_CI_SERVER_CHECKS_ALERT_DAYS="14"
  export GETENT_RESULT=0
  export SSL_CONNECT_RESULT=0
  export SSL_CHECKEND_RESULT=0

  cat > "$TEST_BIN/getent" <<'SCRIPT'
#!/usr/bin/env bash
exit "${GETENT_RESULT:-0}"
SCRIPT

  cat > "$TEST_BIN/timeout" <<'SCRIPT'
#!/usr/bin/env bash
shift
exec "$@"
SCRIPT

  cat > "$TEST_BIN/openssl" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  s_client)
    if [[ "${SSL_CONNECT_RESULT:-0}" != "0" ]]; then
      exit "$SSL_CONNECT_RESULT"
    fi
    printf 'FAKE CERTIFICATE\n'
    exit 0
    ;;
  x509)
    if [[ " $* " == *" -out "* ]]; then
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-out" ]]; then
          cat >/dev/null
          printf 'FAKE CERTIFICATE\n' > "$2"
          exit 0
        fi
        shift
      done
    fi
    for arg in "$@"; do
      if [[ "$arg" == "-checkend" ]]; then
        exit "${SSL_CHECKEND_RESULT:-0}"
      fi
    done
    exit 0
    ;;
esac
exit 0
SCRIPT

  chmod +x "$TEST_BIN/getent" "$TEST_BIN/timeout" "$TEST_BIN/openssl"
}

teardown() {
  rm -rf "$TEST_BIN"
}

@test "passes when DNS and SSL checks pass" {
  run "$PWD/hooks/pre-command"
  assert_success
  assert_output --partial "DNS and HTTPS certificate checks passed for example.com"
}

@test "fails when DNS resolution fails" {
  export GETENT_RESULT=2
  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "DNS resolution failed for example.com"
}

@test "fails when the HTTPS certificate cannot be retrieved" {
  export SSL_CONNECT_RESULT=1
  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "could not retrieve and validate the HTTPS certificate"
}

@test "fails when the certificate expires within the threshold" {
  export SSL_CHECKEND_RESULT=1
  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "expires within 14 days"
}

@test "rejects an invalid domain" {
  export BUILDKITE_PLUGIN_CI_SERVER_CHECKS_DOMAIN="https://example.com/path"
  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "invalid domain format"
}

@test "rejects a non-positive expiry threshold" {
  export BUILDKITE_PLUGIN_CI_SERVER_CHECKS_ALERT_DAYS="0"
  run "$PWD/hooks/pre-command"
  assert_failure
  assert_output --partial "must be a positive integer"
}
