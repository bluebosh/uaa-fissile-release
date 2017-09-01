#!/usr/bin/env bash

# This generates certificates for UAA

set -o errexit -o nounset

load_env() {
    local dir="${1}"
    local files=($(find "${dir}" -maxdepth 1 -name '*.env' '(' -name certs.env -o -print ')' | sort))
    if test "${#files[@]}" -lt 1 ; then
        echo "No environment files found in ${dir}" >&2
        exit 1
    fi
    local f
    for f in "${files[@]}" ; do
        if ! test -e "${f}" ; then
            echo "Invalid environment file ${f}" >&2
            exit 1
        fi
        # shellcheck disable=SC1090
        source "${f}"
        has_env=yes
    done
}

has_env=no

while getopts e: opt ; do
    case "$opt" in
        e)
            if ! test -d "${OPTARG}" ; then
                echo "Invalid -${opt} argument ${OPTARG}, must be a directory" >&2
                exit 1
            fi
            load_env "${OPTARG}"
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ "${1:-}" == "--help" ]]; then
cat <<EOL
Usage: generate_dev_certs.sh <OUTPUT_PATH>
EOL
exit 0
fi

output_path="${1:-}"

if test -z "${output_path}" ; then
    printf "%bWarning: outputting to default file%b\n" "\033[0;1;31m" "\033[0m"
    output_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env/certs.env"
fi

if test "${has_env}" = "no" ; then
    load_env "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env/"
fi

# Generate a random signing key passphrase
signing_key_passphrase=$(head -c 32 /dev/urandom | xxd -ps -c 32)

# build and install `certstrap` tool if it's not installed
command -v certstrap > /dev/null 2>&1 || {
  printf "\n"
  for (( i = 30 ; i > 0 ; i -- )) ; do
    printf "\rCertstrap not found; will attempt to automatically install in %s seconds (press Ctrl+C now to abort)...    " "${i}"
    sleep 1
  done
  printf "\n"
  docker run --rm -v "${HOME}/bin":/out:rw golang:1.7 /usr/bin/env GOBIN=/out go get github.com/square/certstrap
  sudo chown "$(id -un):$(id -gn)" "${HOME}/bin/certstrap"
}

# Certificate generation
certs_path="$(mktemp -d -t hcf-certs.XXXXXXXX)"
if test -z "${certs_path}" ; then
    printf "%bFailed to create temporary directory%b\n" "\033[0;1;31m" "\033[0m"
fi
_cleanup () {
    chmod -R u+w "${certs_path}"
    rm -r "${certs_path}"
}
trap  _cleanup EXIT
hcf_certs_path="${certs_path}/hcf"
internal_certs_dir="${certs_path}/internal"

# generate cf ha_proxy certs
# Source: https://github.com/cloudfoundry/cf-release/blob/master/example_manifests/README.md#dns-configuration
rm -rf "${hcf_certs_path}"
mkdir -p "${hcf_certs_path}"
pushd "${hcf_certs_path}" &>/dev/null

openssl genrsa -out hcf.key 4096
openssl req -new -key hcf.key -out hcf.csr -sha512 -subj "/CN=*.${DOMAIN}/C=US"
openssl x509 -req -days 3650 -in hcf.csr -signkey hcf.key -out hcf.crt

# Given a host name (e.g. "api"), produce variations based on:
# - Having HCP_SERVICE_DOMAIN_SUFFIX and not ("api", "api.hcf")
# - Wildcard and not ("api", "*.api")
# - Include "COMPONENT.uaa.svc", "COMPONENT.uaa.svc.cluster", "COMPONENT.uaa.svc.cluster.local"
make_domains() {
    local host_name="$1"
    local result="${host_name},*.${host_name}"
    local i
    for (( i = 0; i < 10; i++ )) ; do
        result="${result},${host_name}-${i}.${host_name}-pod"
    done
    local cluster_name
    for cluster_name in "" .cluster.local ; do
        result="${result},${host_name}.director.svc${cluster_name}"
        result="${result},*.${host_name}.director.svc${cluster_name}"
        for (( i = 0; i < 10; i++ )) ; do
            result="${result},${host_name}-${i}.${host_name}-pod.uaa.svc${cluster_name}"
        done
    done
    if test -n "${DOMAIN:-}" ; then
        result="${result},${host_name}.${DOMAIN},*.${host_name}.${DOMAIN}"
    fi
    if test -n "${HCP_SERVICE_DOMAIN_SUFFIX:-}" ; then
        result="${result},$(tr -d '[[:space:]]' <<EOF
        ${host_name}.${HCP_SERVICE_DOMAIN_SUFFIX},
        *.${host_name}.${HCP_SERVICE_DOMAIN_SUFFIX}
EOF
    )"
    fi
    echo "${result}"
}

make_ha_domains() {
    make_domains "$1"
}

# Instructions from https://github.com/cloudfoundry-incubator/diego-release#generating-tls-certificates

# Generate internal CA
certstrap --depot-path "${internal_certs_dir}" init --common-name "internalCA" --passphrase "${signing_key_passphrase}" --years 10

# generate director certs
director_server_key="${certs_path}/director_private_key.pem"
director_server_crt="${certs_path}/director_ca.crt"

certstrap --depot-path "${internal_certs_dir}" request-cert --common-name "director" --domain "$(make_domains "director")" --passphrase ""
certstrap --depot-path "${internal_certs_dir}" sign "director" --CA internalCA --passphrase "${signing_key_passphrase}"
cp "${internal_certs_dir}/director.crt" "${director_server_crt}"
cat "${internal_certs_dir}/director.crt" "${internal_certs_dir}/director.key" > "${director_server_key}"

# escape_file_contents reads the given file and replaces newlines with the literal string '\n'
escape_file_contents() {
    # Add a backslash at the end of each line, then replace the newline with a literal 'n'
    sed 's@$@\\@' < "$1" | tr '\n' 'n'
}
INTERNAL_CA_CERT=$(escape_file_contents "${internal_certs_dir}/internalCA.crt")
DIRECTOR_CERT=$(escape_file_contents "${director_server_crt}")
DIRECTOR_KEY=$(escape_file_contents "${director_server_key}")

popd &>/dev/null

cat <<ENVS > "${output_path}"
INTERNAL_CA_CERT=${INTERNAL_CA_CERT}
DIRECTOR_CERT=${DIRECTOR_CERT}
DIRECTOR_KEY=${DIRECTOR_KEY}
ENVS

echo "DIRECTOR keys for ${DOMAIN} wrote to ${output_path}"
