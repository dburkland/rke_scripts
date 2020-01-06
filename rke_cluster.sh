#!/bin/bash
# Filename:             rke_cluster.sh
# By:                   Dan Burkland
# Date:                 2018-12-31
# Purpose:              Script that can create or destroy a given rancher k8s cluster

# Variables
OPERATION="$1"
CLUSTERNAME="$2"

if [[ $OPERATION == "create" ]]; then
  # Setup the rancher k8s cluster
  rke up --config rke_config_${CLUSTERNAME}.yml
  sleep 60
  export KUBECONFIG="$(pwd)/kube_config_rke_config_${CLUSTERNAME}.yml"
  kubectl get nodes
  kubectl get pods --all-namespaces

  # Setup & configure helm
# Commented out lines below as helm 3 removes tiller
#  kubectl -n kube-system create serviceaccount tiller
#  kubectl create clusterrolebinding tiller --clusterrole cluster-admin  --serviceaccount=kube-system:tiller
#  helm init --service-account tiller
#  kubectl -n kube-system rollout status deploy/tiller-deploy
  helm version
elif [[ $OPERATION == "install_rancher" ]]; then
  # Installs Rancher server on the designated k8s cluster
  KUBECONFIG="${PWD}/kube_config_rke_config_${CLUSTERNAME}.yml"
  
  if [[ ! -f $KUBECONFIG ]]; then
    echo "Kuberentes configuration issue detected. Please verify that your k8s config file exists!"
    exit 1
  else
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm install rancher-latest/rancher --name rancher --namespace cattle-system --set hostname=mn1rancher01.dburkland.com --set tls=external --set addLocal=false
    kubectl -n cattle-system rollout status deploy/rancher
  fi
elif [[ $OPERATION == "destroy" ]]; then
  # Destroy the local & remote helm installation along with the rancher k8s cluster
  KUBECONFIG="${PWD}/kube_config_rke_config_${CLUSTERNAME}.yml"
  
  if [[ ! -f $KUBECONFIG ]]; then
    echo "Kuberentes configuration issue detected. Please verify that your k8s config file exists!"
    exit 1
  else
    NODES="$(kubectl get nodes | awk '{ print $1 }' | sed '/NAME/d')"

    helm del --purge rancher

    for node in $NODES; do
      ssh -o StrictHostKeyChecking=no rancher@${node} 'docker stop $(docker ps -a -q); docker rm $(docker ps -a -q); docker volume rm $(docker volume ls -q)'
      ssh -o StrictHostKeyChecking=no rancher@${node} 'docker ps -a'
    done

    rm -f $KUBECONFIG
  fi
else
  echo "Invalid argument"
  echo "Usage: ./rke_cluster [create|install_rancher|destroy] <cluster name>"
fi

#./rke_cluster create -install_rancher false mn1rancher01
