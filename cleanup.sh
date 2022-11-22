#!/bin/bash
#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

set -x -o pipefail

# Use this script to clean up your cluster:
# might be handy if a previous installation failed.

kubectl delete ns tap-installer
kubectl delete ns tanzu-cluster-essentials-bootstrap
kubectl delete ns tanzu-cluster-essentials
kubectl delete ns kapp-controller
kubectl delete ns secretgen-controller
kubectl delete ns tap-install
