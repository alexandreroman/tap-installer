#
# Copyright 2022 VMware Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#

CARVEL_BINARIES := ytt kapp vendir

all: prepare-release

check-carvel:
	$(foreach exec,$(CARVEL_BINARIES),\
		$(if $(shell which $(exec)),,$(error "'$(exec)' not found. Carvel toolset is required. See instructions at https://carvel.dev/#install")))

prepare-release: check-carvel
	mkdir -p out/tap-installer
	ytt -f config -v installer.image=$(shell imgpkg tag resolve -i ghcr.io/alexandreroman/tap-installer) > out/tap-installer/tap-installer-app.yaml && \
	cp config/*.template out/tap-installer

deploy: prepare-release
	kapp deploy --wait-timeout=60m -c -y -a tap-installer -f out/tap-installer

sync: check-carvel
	vendir sync

clean:
	rm -rf out
