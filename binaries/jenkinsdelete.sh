#!/bin/bash

export $(cat /root/.env | xargs)

while true; do
    read -p "Are you sure? [y/n] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf "\n\n\n***********Deleting Jenkins...*************\n"

sleep 2

if [[ -n  $SELFSIGNED_CERT_REGISTRY_URL ]]
then
    printf "\nDelete selfsigned cert configmap...\n"
    awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$SELFSIGNED_CERT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
    kubectl delete -f /tmp/allow-insecure-registries.yaml
    printf "Done.\n"
fi

printf "\n\ndeleting config map for config-as-code plugin\n"
kubectl delete -f ~/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml
printf "Done.\n"

printf "\nDelete Jenkins services..\n"
kubectl delete -f ~/kubernetes/jenkins/service.yaml
printf "Done.\n"

printf "\ndelete Jenkins..\n"
kubectl delete -f ~/kubernetes/jenkins/deployment.yaml
printf "Done.\n"

sleep 5

printf "\nDelete Dockerhub secret..\n"
kubectl delete secret dockerhubregkey --namespace jenkins
printf "Done.\n"

printf "\nDelete service account...\n"
kubectl -n jenkins delete -f ~/kubernetes/jenkins/service-account.yaml
printf "Done.\n"

printf "\nDelete RBAC for Jenkins...\n"
kubectl -n jenkins delete -f ~/kubernetes/jenkins/rbac.yaml
printf "Done.\n"

sleep 2

printf "\nDelete PVC for Jenkins..\n"
awk -v old="JENKINS_PVC_STORAGE_CLASS_NAME" -v new="$JENKINS_PVC_STORAGE_CLASS_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/global/pvc.yaml > /tmp/pvc.yaml
kubectl delete -f /tmp/pvc.yaml
printf "Done.\n"

sleep 5

printf "\nDelete Jenkins namespace..\n"
kubectl delete -f ~/kubernetes/global/namespace.yaml
printf "Done.\n"

printf "\nDelete PSP for Jenkins..\n"
kubectl delete -f ~/kubernetes/global/allow-runasnonroot-clusterrole.yaml
printf "Done.\n"

printf "\n\n"
printf "* DELETED .*\n"
