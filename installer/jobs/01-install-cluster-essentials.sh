#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# Using this script Cluster Essentials for VMware Tanzu
# (including kapp-controller and secretgen-controller)
# will be deployed to your cluster.

BOOTSTRAP_CONFIG=$(mktemp --suffix=.yaml)
cat << EOF > "${BOOTSTRAP_CONFIG}"
#@ load("@ytt:data", "data")
---
apiVersion: v1
kind: Secret
metadata:
  name: tanzu-cluster-essentials-bootstrap-credentials
  namespace: tap-installer
type: Opaque
stringData:
  INSTALL_REGISTRY_USERNAME: #@ data.values.tanzu_network.username
  INSTALL_REGISTRY_PASSWORD: #@ data.values.tanzu_network.password
EOF

if [ ! -z "$(yq '.jobs.skip[] | select(. == "install-cluster-essentials")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip installing Cluster Essentials for VMware Tanzu"
else
  echo "Installing Cluster Essentials for VMware Tanzu"
  ytt -f "${TAP_INSTALLER_CONFIG}" \
      -f "${BOOTSTRAP_CONFIG}" \
      -f "overlays/fix-ns-tanzu-cluster-essentials-bootstrap.yaml" \
      -f "vendor/tanzu-cluster-essentials-bootstrap" | \
    kapp deploy --wait-timeout=30m -c -y -a tanzu-cluster-essentials-bootstrap -f-
fi

# Kickstart next job.
ytt -f jobs/job.tpl.yaml \
    -v job.name=relocate-images \
    -v job.command=${HOME}/jobs/02-relocate-images.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-relocate-images -f-
