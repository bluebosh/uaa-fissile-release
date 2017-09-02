NEW_IP=$1
if [[ $NEW_IP = "" ]]; then
    echo "[ERROR] You must specify your ip as the first argument."
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
sed -i "s/192.168.77.77/$NEW_IP/g" `grep 192.168.77.77 -rl kube/bosh`
grep -rn $NEW_IP kube/bosh
echo "Done!"
