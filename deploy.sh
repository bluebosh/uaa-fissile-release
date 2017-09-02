set -x

kubectl create namespace cpi
kubectl create -n cpi -f kube/bosh/
kubectl create -n cpi -f kube/secrets/
