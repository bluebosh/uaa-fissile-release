set -e
#set -x

CLUSTER_NAME=$1
if [[ $CLUSTER_NAME = "" ]]; then
    echo "[ERROR] You must specify your cluster name as the first argument."
    exit 1
fi

NAMESPACE=$2
if [[ $NAMESPACE = "" ]]; then
    echo "[WARNING] You didn't specify your namespace as the second argument, use bosh as default."
    NAMESPACE=bosh
fi

echo
echo "[INFO] Modify for kube config"
echo "[INFO] Modify storage-class"
sed -i "s/volume.beta.kubernetes.io\/storage-class: persistent/volume.beta.kubernetes.io\/storage-class: ibmc-file-gold\n        volume.beta.kubernetes.io\/storage-provisioner: ibm.io\/ibmc-file/g" `grep storage: -rl kube/bosh`
grep -rn volume.beta.kubernetes.io kube/bosh
echo "Done!"

echo
node_ip=$(bx cs workers $CLUSTER_NAME | awk '/kube.*-w1/{ print $2 }')
echo "[INFO] Modify to use node ip $node_ip"
sed -i "s/192.168.77.77/$node_ip/g" `grep externalIPs -rl kube/bosh`
grep -rn $node_ip kube/bosh
echo "Done!"

echo
kube_config=`kubectl config view | grep "user: http"`
USER=`echo ${kube_config#*#}`
CLUSTER_SERVER=$(kubectl config view -o json | jq -r '.clusters[] | select(.name=="'$CLUSTER_NAME'") | .cluster.server')
CLUSTER_SERVER=$(echo $CLUSTER_SERVER | sed "s/\//\\\\\//g")
cluster_ca_file=$(kubectl config view -o json | jq -r '.clusters[] | select(.name=="'$CLUSTER_NAME'") | .cluster."certificate-authority"')
cluster_path=$HOME/.bluemix/plugins/container-service/clusters/${CLUSTER_NAME}
CLUSTER_CERTIFICATE_AUTHORITY_DATA=$(sed ':a;N;$ s/\n/\\\\n/g;ba' $cluster_path/$cluster_ca_file)
#CLUSTER_CERTIFICATE_AUTHORITY_DATA=$(cat $cluster_path/$cluster_ca_file | sed "s/\//\\\\\//g")
CLUSTER_CERTIFICATE_AUTHORITY_DATA=$(echo $CLUSTER_CERTIFICATE_AUTHORITY_DATA | sed "s/\//\\\\\//g")
CLUSTER_TOKEN=$(kubectl config view -o json | jq -r '.users[] | select(.name=="https://iam.ng.bluemix.net/kubernetes#'$USER'") | .user."auth-provider"."config"."id-token"')
CLUSTER_TOKEN=$(echo $CLUSTER_TOKEN | sed "s/\//\\\\\//g")
CLUSTER_REFRESH_TOKEN=$(kubectl config view -o json | jq -r '.users[] | select(.name=="https://iam.ng.bluemix.net/kubernetes#'$USER'") | .user."auth-provider"."config"."refresh-token"')
CLUSTER_REFRESH_TOKEN=$(echo $CLUSTER_REFRESH_TOKEN | sed "s/\//\\\\\//g")
echo "[INFO] Get Armada cluster $CLUSTER_NAME info such as USER: $USER and CLUSTER_SERVER: $CLUSTER_SERVER and replace them..."

BOSH_YAML=kube/bosh/bosh.yaml
sed -i "s/armada_cluster_certificate_authority_data/$CLUSTER_CERTIFICATE_AUTHORITY_DATA/g" $BOSH_YAML
sed -i "s/armada_cluster_name/$CLUSTER_NAME/g" $BOSH_YAML
sed -i "s/armada_cluster_refresh_token/$CLUSTER_REFRESH_TOKEN/g" $BOSH_YAML
sed -i "s/armada_cluster_server/$CLUSTER_SERVER/g" $BOSH_YAML
sed -i "s/armada_cluster_token/$CLUSTER_TOKEN/g" $BOSH_YAML 
cat $BOSH_YAML

echo
echo "[INFO] Deploy on Armada cluster: $CLUSTER_NAME, namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE
kubectl create -n $NAMESPACE -f kube/secrets/
kubectl create -n $NAMESPACE -f kube/bosh
sleep 10s
kubectl get pods -n $NAMESPACE
