cluster_name=$1
if [[ $cluster_name = "" ]]; then
    echo "[ERROR] You must specify your cluster name as the first argument."
    exit 1
fi

echo
echo "[INFO] Modify for helm config"
echo "[INFO] Modify storage-class"
sed -i "s/volume.beta.kubernetes.io\/storage-class: {{ .Values.kube.storage_class.persistent | quote }}/volume.beta.kubernetes.io\/storage-class: ibmc-file-gold\n        volume.beta.kubernetes.io\/storage-provisioner: ibm.io\/ibmc-file/g" `grep storage: -rl helm/templates/`
grep -rn volume.beta.kubernetes.io helm/templates/
echo "Done!"

echo
echo "[INFO] Modify IP"
node_ip=$(bx cs workers $cluster_name | awk '/kube.*-w1/{ print $2 }')
sed -i "s/192.168.77.77/$node_ip/g" `grep 192.168.77.77 -rl helm/`
grep -rn $node_ip helm/
echo "Done!"
