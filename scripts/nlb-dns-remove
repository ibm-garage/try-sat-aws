#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

CLUSTER_NAME=$1

NLB_HOST=$(ibmcloud ks nlb-dns ls --cluster "${CLUSTER_NAME}" | tail -1 | cut -f1 -d' ')
NLB_IP=$(ibmcloud ks nlb-dns ls --cluster "${CLUSTER_NAME}" | tail -1 | cut -d' ' -f4)

# Only remove NLB IP if there is one (seems to be unpredictable at this stage).
if [[ ${NLB_IP} != "-" ]]; then
    for IP in $(echo ${NLB_IP//,/ }); do
        # Sometimes the following line appears to have failed, but actually
        # passed, which is why we then check with 'nlb-dns ls'.
        ibmcloud ks nlb-dns rm classic --cluster "${CLUSTER_NAME}" --nlb-host "${NLB_HOST}" --ip "${IP}" || true
        while ibmcloud ks nlb-dns ls --cluster "${CLUSTER_NAME}" | grep "${IP}" > /dev/null; do 
            echo "Waiting to remove NLB IP ${IP}..."; sleep 30;
            ibmcloud ks nlb-dns rm classic --cluster "${CLUSTER_NAME}" --nlb-host "${NLB_HOST}" --ip "${IP}" || true
        done
        echo "IP ${IP} successfully removed."
    done
fi
