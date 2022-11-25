#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This script creates the TAP apps namespace.

TAP_APPS_NS=${TAP_APPS_NS:-tap-apps}

NS_CONFIG=$(mktemp --suffix=.yaml)
cat << EOF > "${NS_CONFIG}"
#@ load("@ytt:data", "data")
#@ load("@ytt:json", "json")
---
apiVersion: v1
kind: Namespace
metadata:
  name: $TAP_APPS_NS
---
#@ def config():
#@   return {
#@     "auths": {
#@       data.values.registry.hostname: {
#@         "username": data.values.registry.username,
#@         "password": data.values.registry.password
#@       }
#@     }
#@   }
#@ end
---
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: $TAP_APPS_NS
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: #@ json.encode(config())
---
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  namespace: $TAP_APPS_NS
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: $TAP_APPS_NS
secrets:
- name: registry-credentials
imagePullSecrets:
- name: registry-credentials
- name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
  namespace: $TAP_APPS_NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
- kind: ServiceAccount
  name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
  namespace: $TAP_APPS_NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
- kind: ServiceAccount
  name: default
EOF

if [ ! -z "$(yq '.jobs.skip[] | select(. == "create-apps-namespace")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip creating apps namespace $TAP_APPS_NS"
else
  echo "Creating apps namespace $TAP_APPS_NS"
  ytt -f "${TAP_INSTALLER_CONFIG}" \
      -f "${NS_CONFIG}" | \
    kapp deploy -c -y -a tap-ns-apps -f-
fi

# Kickstart next job.
ytt -f jobs/job.tpl.yaml \
    -v job.name=install-tap \
    -v job.command=${HOME}/jobs/06-install-tap.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-install-tap -f-
