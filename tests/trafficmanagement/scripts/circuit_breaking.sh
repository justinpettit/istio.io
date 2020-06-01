#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2154

# Copyright 2020 Istio Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -u
set -o pipefail

source "${REPO_ROOT}/content/en/docs/tasks/traffic-management/circuit-breaking/snips.sh"
source "${REPO_ROOT}/tests/util/samples.sh"

kubectl label namespace default istio-injection=enabled --overwrite

# Launch the httpbin sample
startup_httpbin_sample

# Create destination rule
snip_configuring_the_circuit_breaker_1

# Confirm destination rule set
_run_and_verify_elided snip_configuring_the_circuit_breaker_2 "$snip_configuring_the_circuit_breaker_2_out"

# Deploy fortio client
snip_adding_a_client_1

_wait_for_deployment default fortio-deploy

# Make one call to httpbin
_run_and_verify_contains snip_adding_a_client_3 "HTTP/1.1 200 OK"

# FIXME / TODO: These tests previously relied on checking that the
# percentage of 200 and 503 responses fell within a given range. That
# turned out to be flaky, so for now they are only checking that both
# 200 and 503 responses are recorded, and ignoring the number of each.
# That should be fixed at some point.
#
#    Original PR: https://github.com/istio/istio.io/pull/6609
#  Temporary fix: https://github.com/istio/istio.io/pull/7043
#          Issue: https://github.com/istio/istio.io/issues/7074

# Make requests with 2 connections
out=$(snip_tripping_the_circuit_breaker_1 2>&1)
_verify_contains "$out" "Code 200 :" "snip_tripping_the_circuit_breaker_1"
_verify_contains "$out" "Code 503 :" "snip_tripping_the_circuit_breaker_1"

# Make requests with 3 connections
out=$(snip_tripping_the_circuit_breaker_3 2>&1)
_verify_contains "$out" "Code 200 :" "snip_tripping_the_circuit_breaker_3"
_verify_contains "$out" "Code 503 :" "snip_tripping_the_circuit_breaker_3"

# Query the istio-proxy stats
out=$(snip_tripping_the_circuit_breaker_5 2>&1)
expected="cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.circuit_breakers.default.rq_pending_open: ...
cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.circuit_breakers.high.rq_pending_open: ...
cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.upstream_rq_pending_active: ...
cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.upstream_rq_pending_failure_eject: ...
cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.upstream_rq_pending_overflow: ...
cluster.outbound|8000||httpbin.istio-io-circuitbreaker.svc.cluster.local.upstream_rq_pending_total: ..."
_verify_like "$out" "$expected" "snip_tripping_the_circuit_breaker_5"
