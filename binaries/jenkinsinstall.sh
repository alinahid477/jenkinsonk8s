#!/bin/bash
export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
printf "\n\n\n***********Starting installation of Jenkins...*************\n"

printf "\n\n\n**********vSphere Cluster login...*************\n"


printf "\n\n\n***********Checking kubeconfig...*************\n"

EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$TKG_VSPHERE_CLUSTER_ENDPOINT'/{flag2=1} flag2 && /token:/ {print $NF;exit}' /root/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')

if [ -z "$EXISTING_JWT_EXP" ]
then
    EXISTING_JWT_EXP=$(date  --date="yesterday" +%s)
    # printf "\n SET EXP DATE $EXISTING_JWT_EXP"
fi
CURRENT_DATE=$(date +%s)

if [ "$CURRENT_DATE" -gt "$EXISTING_JWT_EXP" ]
then
    printf "\n\n\n***********Login into cluster...*************\n"
    if [ -z "$BASTION_HOST" ]
    then
        rm /root/.kube/config
        rm -R /root/.kube/cache
        kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
        kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
    else
        printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
        ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST

        
        rm /root/.kube/config
        rm -R /root/.kube/cache
        kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
        sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
        kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
        sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config

        printf "\n\n\n***********Jenkins will be installed in the below cluster...*************\n"
        kubectl get ns
    fi
else
    printf "\n\n\nCuurent kubeconfig has not expired. Using the existing one found at .kube/config\n"
    if [ -n "$BASTION_HOST" ]
    then
        printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
    fi
    printf "\n\n\n***********This docker is now connected to the below cluster...*************\n"
    kubectl get ns
fi

if [ -z "$COMPLETE" ]
then
    printf "\n\n\n***********Prepare cluster for Jenkins...*************\n"
    printf "\n"

    printf "\nPOD security policy:"
    kubectl apply -f ~/kubernetes/global/allow-runasnonroot-clusterrole.yaml
    printf "\nDone."

    printf "\nCreate namespace for Jenkins:"
    kubectl apply -f ~/kubernetes/global/namespace.yaml
    printf "\nDone."

    printf "\nCreate PVC for Jenkins:"
    kubectl apply -f ~/kubernetes/global/pvc.yaml
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

    printf "\nIntegration to Harbor private registry:"
    awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$SELFSIGNED_CERT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
    kubectl apply -f /tmp/allow-insecure-registries.yaml
    printf "\nDone."

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