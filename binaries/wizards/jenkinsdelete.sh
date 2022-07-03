#!/bin/bash

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

function deleteJenkins () {


    local confirmation=''
    while true; do
        read -p "Are you sure? [y/n] " yn
        case $yn in
            [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) confirmation='n'; printf "\nYou confirmed no.\n"; break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1
    fi

    printf "\n\n\n***********Deleting Jenkins...*************\n"

    sleep 2

    if [[ $JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT == 'y' ]]
    then
        printf "\nDelete selfsigned cert configmap...\n"
        awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$JENKINS_SECRET_PVT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/binaries/templates/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
        kubectl delete -f /tmp/allow-insecure-registries.yaml
        printf "Done.\n"
    fi

    printf "\nDeleting config map for config-as-code plugin...\n"
    kubectl delete -f ~/binaries/templates/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml
    printf "Done.\n"

    printf "\nDelete Jenkins services...\n"
    kubectl delete -f ~/binaries/templates/kubernetes/jenkins/service.yaml
    printf "Done.\n"

    printf "\nDelete Jenkins...\n"
    kubectl delete -f ~/binaries/templates/kubernetes/jenkins/deployment.yaml
    printf "Done.\n"

    sleep 5

    printf "\nDelete Dockerhub secret: jenkinsdockerhubregkey...\n"
    kubectl delete secret jenkinsdockerhubregkey --namespace jenkins
    printf "Done.\n"

    printf "\nDelete service account...\n"
    kubectl -n jenkins delete -f ~/binaries/templates/kubernetes/jenkins/service-account.yaml
    printf "Done.\n"

    printf "\nDelete RBAC for Jenkins...\n"
    kubectl -n jenkins delete -f ~/binaries/templates/kubernetes/jenkins/rbac.yaml
    printf "Done.\n"

    sleep 2

    printf "\nDelete PVC for Jenkins...\n"
    awk -v old="JENKINS_PVC_STORAGE_CLASS_NAME" -v new="$JENKINS_PVC_STORAGE_CLASS_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/kubernetes/global/pvc.yaml > /tmp/pvc.yaml
    kubectl delete -f /tmp/pvc.yaml
    printf "Done.\n"

    sleep 5

    printf "\nDelete Jenkins namespace...\n"
    kubectl delete -f ~/binaries/templates/kubernetes/global/namespace.yaml
    printf "Done.\n"

    printf "\nDelete PSP for Jenkins...\n"
    kubectl delete -f ~/binaries/templates/kubernetes/global/allow-runasnonroot-clusterrole.yaml
    printf "Done.\n"

    printf "\n\n"
    printf "* DELETED .*\n"
}



