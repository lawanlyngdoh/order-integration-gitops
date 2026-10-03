#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${repository_root}/.rendered"

mkdir -p "${output_directory}"

environments=(dev test prod)

for environment in "${environments[@]}"; do
    overlay="${repository_root}/apps/order-integration/overlays/${environment}"
    rendered_manifest="${output_directory}/${environment}.yaml"
    namespace="order-${environment}"

    echo "Rendering ${environment}"

    kubectl kustomize "${overlay}" >"${rendered_manifest}"

    if ! grep -Eq \
        'image: ghcr.io/lawanlyngdoh/order-integration-service@sha256:[0-9a-f]{64}$' \
        "${rendered_manifest}"; then
        echo "${environment}: image is not pinned to a SHA-256 digest"
        exit 1
    fi

    if ! grep -q "namespace: ${namespace}" "${rendered_manifest}"; then
        echo "${environment}: expected namespace ${namespace}"
        exit 1
    fi

    if ! grep -q "ENVIRONMENT: ${environment}" "${rendered_manifest}"; then
        echo "${environment}: environment configuration is incorrect"
        exit 1
    fi
done

if ! grep -q "replicas: 1" "${output_directory}/dev.yaml"; then
    echo "dev: expected one replica"
    exit 1
fi

if ! grep -q "replicas: 1" "${output_directory}/test.yaml"; then
    echo "test: expected one replica"
    exit 1
fi

if ! grep -q "replicas: 2" "${output_directory}/prod.yaml"; then
    echo "prod: expected two replicas"
    exit 1
fi

echo "All environment policies passed"