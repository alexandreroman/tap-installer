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
profile: #@ data.values.profile

excluded_packages:
- learningcenter.tanzu.vmware.com
- workshops.learningcenter.tanzu.vmware.com

#@ if/end "supply_chain" in data.values.tap:
supply_chain: #@ data.values.tap.supply_chain
ootb_supply_chain_basic:
  #@ if "git" in data.values:
  gitops:
    ssh_secret: git-credentials
    #@ if "gitops" in data.values.git:
    server_address: #@ "https://{}".format(data.values.git.hostname)
    repository_owner: #@ data.values.git.gitops.repository_owner
    repository_name: #@ data.values.git.gitops.repository_name
    branch: #@ data.values.git.gitops.branch
    #@ end
  #@ end
ootb_supply_chain_testing:
  #@ if "git" in data.values:
  gitops:
    ssh_secret: git-credentials
    #@ if "gitops" in data.values.git:
    server_address: #@ "https://{}".format(data.values.git.hostname)
    repository_owner: #@ data.values.git.gitops.repository_owner
    repository_name: #@ data.values.git.gitops.repository_name
    branch: #@ data.values.git.gitops.branch
    #@ end
  #@ end
ootb_supply_chain_testing_scanning:
  #@ if "git" in data.values:
  gitops:
    ssh_secret: git-credentials
    #@ if "gitops" in data.values.git:
    server_address: #@ "https://{}".format(data.values.git.hostname)
    repository_owner: #@ data.values.git.gitops.repository_owner
    repository_name: #@ data.values.git.gitops.repository_name
    branch: #@ data.values.git.gitops.branch
    #@ end
  #@ end

contour:
  envoy:
    service:
      type: LoadBalancer
      #@ if/end "ingress" in data.values.tap and "envoy" in data.values.tap.ingress and "loadBalancerIP" in data.values.tap.ingress.envoy:
      loadBalancerIP: #@ data.values.tap.ingress.envoy.loadBalancerIP
      #@ if/end "ingress" in data.values.tap and "envoy" in data.values.tap.ingress and "annotations" in data.values.tap.ingress.envoy:
      annotations: #@ data.values.tap.ingress.envoy.annotations

#@ if data.values.profile == "full" or data.values.profile == "iterate" or data.values.profile == "view":
tap_gui:
  service_type: ClusterIP
  deployment:
    #@ if/end "instances" in data.values.tap and data.values.tap.instances:
    replicas: #@ data.values.tap.instances
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
    #@ if "metadata_store" in data.values.tap and data.values.tap.metadata_store.token:
    proxy:
      /metadata-store:
        target: https://metadata-store-app.metadata-store:8443/api/v1
        changeOrigin: true
        secure: false
        headers:
          Authorization: #@ "Bearer {}".format(data.values.tap.metadata_store.token)
          X-Custom-Source: project-star
    #@ end
    #@ if "clusters" in data.values.tap and len(data.values.tap.clusters) > 0:
    kubernetes:
      serviceLocatorMethod:
        type: multiTenant
      clusterLocatorMethods:
      - type: config
        clusters:
        #@ for c in data.values.tap.clusters:
        - #@ c
        #@ end
    #@ end
#@ end

#@ if data.values.profile == "full" or data.values.profile == "build":
metadata_store:
  ns_for_export_app_cert: tap-apps
  app_service_type: ClusterIP

scanning:
  metadataStore:
    url: ""

springboot_conventions:
  autoConfigureActuators: true

grype:
  namespace: tap-apps
  targetImagePullSecret: tap-registry
#@ end

package_overlays:
- name: contour
  secrets:
  - name: overlay-fix-contour-ipv6
- name: ootb-supply-chain-testing-scanning
  secrets:
  - name: overlay-remove-source-scanner
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
---
apiVersion: v1
kind: Secret
metadata:
  name: overlay-fix-contour-ipv6
  namespace: ${TAP_NS}
stringData:
  fix-contour-ipv6.yml: |
    #@ load("@ytt:overlay", "overlay")
    #@overlay/match by=overlay.subset({"kind": "Deployment"}),expects=1
    ---
    spec:
      template:
        spec:
          containers:
          #@overlay/match by=overlay.map_key("name")
          - name: contour
            #@overlay/replace
            args:
            - serve
            - --incluster
            - '--xds-address=0.0.0.0'
            - --xds-port=8001
            - '--stats-address=0.0.0.0'
            - '--http-address=0.0.0.0'
            - '--envoy-service-http-address=0.0.0.0'
            - '--envoy-service-https-address=0.0.0.0'
            - '--health-address=0.0.0.0'
            - --contour-cafile=/certs/ca.crt
            - --contour-cert-file=/certs/tls.crt
            - --contour-key-file=/certs/tls.key
            - --config-path=/config/contour.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: overlay-remove-source-scanner
  namespace: ${TAP_NS}
type: Opaque
stringData:
  ootb-supply-chain-testing-scanning-remove-source-scanner.yaml: |
    #@ load("@ytt:overlay", "overlay")
    #@overlay/match by=overlay.subset({"metadata":{"name":"source-test-scan-to-url"}, "kind": "ClusterSupplyChain"})
    ---
    spec:
      resources:
      #@overlay/match by="name"
      #@overlay/remove
      - name: source-scanner
      #@overlay/match by="name"
      - name: image-provider
        sources:
        #@overlay/match by="name"
        - name: source
          resource: source-tester
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
