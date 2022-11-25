#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This script creates the namespace for TAP.

TAP_NS=${TAP_NS:-tap-install}


if [ ! -z "$(yq '.jobs.skip[] | select(. == "create-namespace")' $TAP_INSTALLER_CONFIG)" ]; then
  echo "Skip creating namespace $TAP_NS"
else
  echo "Creating namespace $TAP_NS"
  cat << EOF | kapp deploy -c -y -a tap-ns -f-
apiVersion: v1
kind: Namespace
metadata:
  name: $TAP_NS
EOF
fi

# Kickstart next job.
echo "Kickstarting next job: add-repo"
ytt -f jobs/job.tpl.yaml \
    -v job.name=add-repo \
    -v job.command=${HOME}/jobs/04-add-repo.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-add-repo -f-
