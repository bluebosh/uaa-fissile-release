cluster_name=$1
if [[ $cluster_name = "" ]]; then
    echo "[ERROR] You must specify your cluster name as the first argument."
    exit 1
fi

echo
echo "[INFO] Modify for kube config"
echo "[INFO] Modify storage-class"
sed -i "s/volume.beta.kubernetes.io\/storage-class: persistent/volume.beta.kubernetes.io\/storage-class: ibmc-file-gold\n        volume.beta.kubernetes.io\/storage-provisioner: ibm.io\/ibmc-file/g" `grep storage: -rl kube/bosh`
grep -rn volume.beta.kubernetes.io kube/bosh
echo "Done!"

echo
echo "[INFO] Modify IP"
node_ip=$(bx cs workers $cluster_ip | awk '/kube.*-w1/{ print $2 }')
sed -i "s/192.168.77.77/$node_ip/g" `grep 192.168.77.77 -rl kube/`
grep -rn $node_ip kube/
echo "Done!"
