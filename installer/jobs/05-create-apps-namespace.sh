#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This script creates the TAP apps namespace.

TAP_APPS_NS=${TAP_APPS_NS:-tap-apps}

if [ ! -z "$(yq '.jobs.skip[] | select(. == "create-apps-namespace")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip creating apps namespace $TAP_APPS_NS"
else
  echo "Creating apps namespace $TAP_APPS_NS"
cat << EOF | kapp deploy -c -y -a tap-ns-apps -f-
apiVersion: v1
kind: Namespace
metadata:
  name: $TAP_APPS_NS
EOF
fi

# Kickstart next job.
ytt -f jobs/job.tpl.yaml \
    -v job.name=install-tap \
    -v job.command=${HOME}/jobs/06-install-tap.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-install-tap -f-
