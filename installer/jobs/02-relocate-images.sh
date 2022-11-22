#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This script takes care of relocating TAP images
# from Tanzu Network to your private registry.

TANZU_NET_USERNAME=$(yq .tanzu_network.username ${TAP_INSTALLER_CONFIG})
TANZU_NET_PASSWORD=$(yq .tanzu_network.password ${TAP_INSTALLER_CONFIG})
TANZU_NET_HOSTNAME=registry.tanzu.vmware.com

TAP_REGISTRY_USERNAME=$(yq .registry.username ${TAP_INSTALLER_CONFIG})
TAP_REGISTRY_PASSWORD=$(yq .registry.password ${TAP_INSTALLER_CONFIG})
TAP_REGISTRY_HOSTNAME=$(yq .registry.hostname ${TAP_INSTALLER_CONFIG})

TAP_REPO=$(yq .registry.repository ${TAP_INSTALLER_CONFIG})

# Set up registry credentials for imgpkg:
# see details in https://carvel.dev/imgpkg/docs/latest/auth/#via-docker-config.

mkdir -p ${HOME}/.docker
cat << EOF > ${HOME}/.docker/config.json
{
  "auths": {
    "${TANZU_NET_HOSTNAME}": {
      "auth": "$(echo -n ${TANZU_NET_USERNAME}:${TANZU_NET_PASSWORD} | base64)"
    },
    "${TAP_REGISTRY_HOSTNAME}": {
      "auth": "$(echo -n ${TAP_REGISTRY_USERNAME}:${TAP_REGISTRY_PASSWORD} | base64)"
    }
  }
}
EOF

if [ ! -z "$(yq '.jobs.skip[] | select(. == "relocate-images")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip relocating images to private registry"
else
  echo "Relocating images to private registry"
  # Note: debug output is enabled to track progress.
  imgpkg copy -b ${TANZU_NET_HOSTNAME}/tanzu-application-platform/tap-packages:${TAP_VERSION} \
         --to-repo ${TAP_REGISTRY_HOSTNAME}/${TAP_REPO}/tap-packages \
         --registry-insecure --debug
fi

# Kickstart next job.
ytt -f jobs/job.tpl.yaml \
    -v job.name=create-namespace \
    -v job.command=${HOME}/jobs/03-create-namespace.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-create-namespace -f-
