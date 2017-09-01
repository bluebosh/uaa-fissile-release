echo "Get all submodules"
git submodule update --init --recursive

echo
echo "Download blobs for kubernetes-cpi-release as workaround"
cd src/kubernetes-cpi-release
wget -P blobs/golang https://storage.googleapis.com/golang/go1.7.3.linux-amd64.tar.gz
wget -P blobs/golang https://storage.googleapis.com/golang/go1.7.3.darwin-amd64.tar.gz
