#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# Run this script to kickstart the TAP installation process.

TAP_NS=${TAP_NS:-tap-install}

# Create TAP configuration file.
TAP_CONFIG=$(mktemp --suffix=.yaml)
cat << EOF > "${TAP_CONFIG}"
#@ load("@ytt:data", "data")
#@ load("@ytt:yaml", "yaml")
---
#@ def values():
shared:
  ingress_domain: #@ data.values.tap.ingress.domain
  image_registry:
    project_path: #@ "{}/{}".format(data.values.registry.hostname, data.values.registry.repository)
    username: #@ data.values.registry.username
    password: #@ data.values.registry.password

ceip_policy_disclosed: true
profile: full

excluded_packages:
- learningcenter.tanzu.vmware.com
- workshops.learningcenter.tanzu.vmware.com
- policy.apps.tanzu.vmware.com
- image-policy-webhook.signing.apps.tanzu.vmware.com

#@ if/end "supply_chain" in data.values.tap:
supply_chain: #@ data.values.tap.supply_chain
ootb_supply_chain_basic:
  gitops:
    ssh_secret: git-credentials
ootb_supply_chain_testing:
  gitops:
    ssh_secret: git-credentials
ootb_supply_chain_testing_scanning:
  gitops:
    ssh_secret: git-credentials

contour:
  envoy:
    service:
      type: LoadBalancer

tap_gui:
  service_type: ClusterIP
  app_config:
    #@ if "title" in data.values.tap:
    customize:
      custom_name: #@ data.values.tap.title
    #@ end
    #@ if "github" in data.values:
    integrations:
      github:
      - host: github.com
        token: #@ data.values.github.access_token
    #@ end
    #@ if "catalog" in data.values.tap:
    catalog:
      locations:
      - type: url
        target: #@ data.values.tap.catalog
    #@ end
    #@ if "db" in data.values.tap:
    backend:
      database:
        client: #@ data.values.tap.db.type if "type" in data.values.tap.db and data.values.tap.db.type else "pg"
        connection:
          host: #@ data.values.tap.db.hostname
          port: #@ data.values.tap.db.port if "port" in data.values.tap.db and data.values.tap.db.port else 5432
          user: #@ data.values.tap.db.username
          password: #@ data.values.tap.db.password
          ssl: {rejectUnauthorized: true}
    #@ end
    #@ if "oidc" in data.values and data.values.oidc.provider == "github":
    auth:
      environment: tap
      providers:
        github:
          tap:
            clientId: #@ data.values.oidc.client_id
            clientSecret: #@ data.values.oidc.client_secret
    #@ end

metadata_store:
  ns_for_export_app_cert: tap-apps
  app_service_type: ClusterIP

scanning:
  metadataStore:
    url: ""

grype:
  namespace: tap-apps
  targetImagePullSecret: tap-registry
#@ end
---
apiVersion: v1
kind: Secret
metadata:
  name: tap-values
  namespace: ${TAP_NS}
  annotations:
    kapp.k14s.io/change-group: tap-install/pkg
    kapp.k14s.io/change-rule: upsert after upserting tap-install/rbac
    kapp.k14s.io/change-rule.repo: upsert after upserting tap-install/tap-repo
type: Opaque
stringData:
  values.yml: #@ yaml.encode(values())
EOF

# Create TAP package install.
TAP_PKG=$(mktemp --suffix=.yaml)
cat << EOF > "${TAP_PKG}"
#@ load("@ytt:data", "data")
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: tap
  namespace: ${TAP_NS}
  annotations:
    kapp.k14s.io/disable-wait: ""
    kapp.k14s.io/change-group: tap-install/pkg
    kapp.k14s.io/change-rule: upsert after upserting tap-install/rbac
    kapp.k14s.io/change-rule.repo: upsert after upserting tap-install/tap-repo
spec:
  packageRef:
    refName: tap.tanzu.vmware.com
    versionSelection:
      constraints: "${TAP_VERSION}"
      prereleases: {}
  serviceAccountName: tap-install-job-sa
  syncPeriod: 60m
  values:
  - secretRef:
      name: tap-values
EOF

# Create TAP RBAC used for package installation.
TAP_RBAC=$(mktemp --suffix=.yaml)
cat << EOF > "${TAP_RBAC}"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tap-install-job-sa
  namespace: ${TAP_NS}
  annotations:
    kapp.k14s.io/change-group: tap-install/rbac
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tap-install-job-role
  annotations:
    kapp.k14s.io/change-group: tap-install/rbac
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-install-job-role-binding
  annotations:
    kapp.k14s.io/change-group: tap-install/rbac
subjects:
- kind: ServiceAccount
  name: tap-install-job-sa
  namespace: ${TAP_NS}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tap-install-job-role
EOF

if [ ! -z "$(yq '.jobs.skip[] | select(. == "install-tap")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip installing TAP"
else
  echo "Installing TAP ${TAP_VERSION}"
  # Kickstart TAP installatinon.
  ytt -f "${TAP_INSTALLER_CONFIG}" \
      -f "${TAP_CONFIG}" \
      -f "${TAP_PKG}" \
      -f "${TAP_RBAC}" | \
    kapp deploy --wait-timeout=60m -c -y -a tap-install -f-
fi
