#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This script installs the TAP package repository.

TAP_NS=${TAP_NS:-tap-install}

# Create credentials for accessing the registry.
REGISTRY_CONFIG=$(mktemp --suffix=.yaml)
cat << EOF > "${REGISTRY_CONFIG}"
#@ load("@ytt:data", "data")
#@ load("@ytt:base64", "base64")
#@ load("@ytt:json", "json")
---
#@ def config():
#@  return {
#@    "auths": {
#@      data.values.registry.hostname: {
#@        "username": data.values.registry.username,
#@        "password": data.values.registry.password
#@      }
#@    }
#@  }
#@ end
---
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  namespace: ${TAP_NS}
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: #@ json.encode(config())
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: tap-registry
  namespace: ${TAP_NS}
spec:
  toNamespaces:
  - '*'
EOF

# Add the TAP package repository.
REPO_CONFIG=$(mktemp --suffix=.yaml)
cat << EOF > "${REPO_CONFIG}"
#@ load("@ytt:data", "data")
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: tanzu-tap-repository
  namespace: ${TAP_NS}
spec:
  fetch:
    imgpkgBundle:
      image: #@ "{}/{}/tap-packages:{}".format(data.values.registry.hostname, data.values.registry.repository, "${TAP_VERSION}")
      secretRef:
        name: tap-registry
---
apiVersion: kapp.k14s.io/v1alpha1
kind: Config
minimumRequiredVersion: 0.29.0
waitRules:
- supportsObservedGeneration: true
  conditionMatchers:
  - type: ReconcileFailed
    status: "True"
    failure: true
  - type: ReconcileSucceeded
    status: "True"
    success: true
  resourceMatchers:
  - apiVersionKindMatcher:
      apiVersion: packaging.carvel.dev/v1alpha1
      kind: PackageRepository
EOF

if [ ! -z "$(yq '.jobs.skip[] | select(. == "add-repo")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip adding package repository"
else
  echo "Adding package repository for TAP ${TAP_VERSION}"
  # Deploy everything to the cluster.
  ytt -f "${TAP_INSTALLER_CONFIG}" \
      -f "${REGISTRY_CONFIG}" \
      -f "${REPO_CONFIG}" | \
    kapp deploy -c -y -a tap-repo -f-
fi

# Kickstart next job.
echo "Kickstarting next job: create-apps-namespace"
ytt -f jobs/job.tpl.yaml \
    -v job.name=create-apps-namespace \
    -v job.command=${HOME}/jobs/05-create-apps-namespace.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-create-apps-namespace -f-
