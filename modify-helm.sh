echo
echo "[INFO] Modify for helm config"
echo "[INFO] Modify storage-class"
sed -i "s/volume.beta.kubernetes.io\/storage-class: {{ .Values.kube.storage_class.persistent | quote }}/volume.beta.kubernetes.io\/storage-class: ibmc-file-gold\n        volume.beta.kubernetes.io\/storage-provisioner: ibm.io\/ibmc-file/g" `grep storage: -rl helm/templates/`
grep -rn volume.beta.kubernetes.io helm/templates/
echo "Done!"
