#!/bin/bash

if [ -z "$COMPLETE" ]
then
    if [[ -z $SILENTMODE ]]
    then
        printf "\n\n\n***********The cluster has below storage policies...*************\n"
        kubectl get storageclass
        printf "\nPlease confirm that you have added value from the above as the value for JENKINS_PVC_STORAGE_CLASS_NAME in the .env file."
        printf "\nIf not, now is the time to do so."
        printf "\nOnce you have added the right value in the .env file confirm y to continue.\n"
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
    export $(cat /root/.env | xargs)

    printf "\n\n\n***********Starting installation of Jenkins...*************\n"

    printf "\n\n\n***********Prepare cluster for Jenkins...*************\n"
    printf "\n"

    printf "\nPOD security policy:"
    kubectl apply -f ~/kubernetes/global/allow-runasnonroot-clusterrole.yaml
    printf "\nDone."

    printf "\nCreate namespace for Jenkins:"
    kubectl apply -f ~/kubernetes/global/namespace.yaml
    printf "\nDone."

    printf "\nCreate PVC for Jenkins:"
    awk -v old="JENKINS_PVC_STORAGE_CLASS_NAME" -v new="$JENKINS_PVC_STORAGE_CLASS_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/global/pvc.yaml > /tmp/pvc.yaml
    kubectl apply -f ~/tmp/pvc.yaml
    printf "\nDone."

    printf "\nCreate Dockerhub secret in kubernetes namespace for Jenkins:"
    kubectl create secret docker-registry dockerhubregkey --docker-server=https://index.docker.io/v2/ --docker-username=$DOCKERHUB_USERNAME --docker-password=$DOCKERHUB_PASSWORD --docker-email=$DOCKERHUB_EMAIL --namespace jenkins
    printf "\nDone."

    printf "\nCreate Service Account with Dockerhub secret name in kubernetes namespace for Jenkins:"
    kubectl -n jenkins apply -f ~/kubernetes/jenkins/service-account.yaml
    printf "\nDone."

    printf "\nCreate RBAC for Jenkins:"
    kubectl -n jenkins apply -f ~/kubernetes/jenkins/rbac.yaml
    printf "\nDone."

    printf "\nVerify get sa and get secret:"
    kubectl get sa -n jenkins
    kubectl get secret -n jenkins
    printf "\nDone."

    if [[ -n  $SELFSIGNED_CERT_REGISTRY_URL ]]
    then
        printf "\nIntegration to Harbor private registry:"
        awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$SELFSIGNED_CERT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
        kubectl apply -f /tmp/allow-insecure-registries.yaml
        printf "\nDone."
    fi
    

    printf "\nDeploy Jenkins:"
    kubectl apply -f ~/kubernetes/jenkins/deployment.yaml
    printf "\nDone."


    printf "\nWait 5 mins for pods to be running:"
    sleep 5m
    printf "\nDone."


    printf "\ncheck replica set status"
    kubectl get rs -n jenkins
    printf "\nDone."

    printf "\ncheck pods status"
    kubectl get pods -n jenkins
    printf "\nDone."

    printf "\nExpose Jenkins through k8s service"
    kubectl apply -f ~/kubernetes/jenkins/service.yaml
    printf "\nDone."

    printf "\nWait 5 mins for svc to have external endpoint:"
    sleep 5m
    printf "\nDone."

    printf "\ncheck svc status and record the external ip"
    kubectl get svc -n jenkins
    printf "\nDone."

    printf "\nCOMPLETE=YES" >> /root/.env

    printf "\n\n"
    printf "***********\n"
    printf "*COMPLETE.*\n"
    printf "***********\n"

    printf "\n\nPlease follow the instructions further to configure Jenkins for k8s. in Readme.md follow from here: STEP 5: CONFIGURE JENKINS\n\n\n"
else
    printf "\n\n\nJenkins deployment is already marked as complete. (If this is not desired please change COMPLETE=\"\" or remove COMPLETE in the .env for new jenkins installation)\n"
    printf "\n\n\nGoing straight to shell access.\n"
fi

/bin/bash