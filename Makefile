#!/usr/bin/env make
ifeq ($(GIT_ROOT),)
GIT_ROOT:=$(shell git rev-parse --show-toplevel)
endif

build: certs releases images

certs:
	${GIT_ROOT}/make/generate-certs.sh

releases:
	${GIT_ROOT}/make/releases

images:
	${GIT_ROOT}/make/images

kube kube/bosh/uaa.yaml:
	${GIT_ROOT}/make/kube

kube-dist:
	${GIT_ROOT}/make/kube-dist

helm:
	${GIT_ROOT}/make/kube helm

publish:
	${GIT_ROOT}/make/publish

.PHONY: build certs releases images kube kube-dist helm publish


run: 
	${GIT_ROOT}/make/run $(cluster_name) $(namespace)

stop:
	${GIT_ROOT}/make/stop

clean:
	${GIT_ROOT}/make/clean

deploy:
	${GIT_ROOT}/make/deploy $(cluster_name) $(init)

deploy_kube:
	${GIT_ROOT}/make/deploy_kube $(cluster_name) $(namespace)

dist: kube-dist

generate: kube

