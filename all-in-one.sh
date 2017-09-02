#!/bin/bash
set -ex

cluster_name=$1
if [[ $cluster_name = "" ]]; then
    echo "[ERROR] You must specify your cluster name as the first argument."
    exit 1
fi

init=$2

echo "[INFO] Deploy Start!!!"

if [ "$init" != "" ]; then
	echo "[INFO] init parameter is not null, init the resources"

	echo
	echo "[INFO] make certs"
	make certs

	echo
	echo "[INFO] make releases"
	make releases

	echo
	echo "[INFO] clean iamges"
	./docker_rm.sh

	echo
	echo "[INFO] make images"
	make images

	echo
	echo "[INFO] make publish"
	make publish
fi

echo
echo "[INFO] make helm"
make helm

echo
echo "[INFO] modify helm config"
./modify-helm.sh $cluster_name

echo
echo "[INFO] make run"
make run cluster_name=$cluster_name

