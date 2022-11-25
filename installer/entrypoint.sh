#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -e -o pipefail

# This is the entrypoint for the TAP Installer.
# This script is responsible for driving the installation
# by relying on Kubernetes Jobs.

TAP_INSTALLER_VERSION=${TAP_INSTALLER_VERSION:-<dev>}
echo "TAP Installer version ${TAP_INSTALLER_VERSION}"
echo "Copyright (c) 2022 VMware Inc. All Rights Reserved."

# Kickstart the first job.
echo "Kickstarting next job: install-cluster-essentials"
ytt -f jobs/job.tpl.yaml \
    -v job.name=install-cluster-essentials \
    -v job.command=${HOME}/jobs/01-install-cluster-essentials.sh \
    -v job.image=${TAP_INSTALLER_IMAGE} | \
  kapp deploy -c -y -a job-install-cluster-essentials -f-
