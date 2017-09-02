function remove_images() {
image_list=`docker images | grep $1 | awk -F ' ' '{print $2}'`
while read line; do
	echo "[INFO] Delete docker image $1:$line"
	docker rmi $1:$line -f
done <<< "$image_list"
}

image_name="bluebosh/bosh-bosh"
remove_images $image_name
echo
image_name="bosh-role-packages"
remove_images $image_name
