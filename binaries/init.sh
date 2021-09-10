#!/bin/bash
printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x


export $(cat /root/.env | xargs)
chmod 600 /root/.ssh/id_rsa

printf "\n\n\n***********Checking kubeconfig...*************\n"


if [[ -n $TKG_VSPHERE_SUPERVISOR_ENDPOINT ]]
then

    IS_KUBECTL_VSPHERE_EXISTS=$(kubectl vsphere)
    if [ -z "$IS_KUBECTL_VSPHERE_EXISTS" ]
    then 
        printf "\n\nkubectl vsphere not installed.\nChecking for binaries...\n"
        IS_KUBECTL_VSPHERE_BINARY_EXISTS=$(ls ~/binaries/ | grep kubectl-vsphere)
        if [ -z "$IS_KUBECTL_VSPHERE_BINARY_EXISTS" ]
        then            
            printf "\n\nDid not find kubectl-vsphere binary in ~/binaries/.\nDownloding in ~/binaries/ directory..."
            if [[ -n $BASTION_HOST ]]
            then
                ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            fi
            curl -kL https://localhost/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
            unzip ~/binaries/vsphere-plugin.zip -d ~/binaries/vsphere-plugin/
            mv ~/binaries/vsphere-plugin/bin/kubectl-vsphere ~/binaries/
            rm -R ~/binaries/vsphere-plugin/
            rm ~/binaries/vsphere-plugin.zip
            fuser -k 443/tcp
            printf "\n\nkubectl-vsphere is now downloaded in ~/binaries/...\n"
        fi
        printf "\n\nAdjusting the dockerfile to incluse kubectl-binaries...\n"
        sed -i '/COPY binaries\/kubectl-vsphere \/usr\/local\/bin\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod +x \/usr\/local\/bin\/kubectl-vsphere/s/^# //' ~/Dockerfile

        printf "\n\nDockerfile is now adjusted with kubectl-vsphre.\n\n"
        printf "\n\nPlease rebuild the docker image and run again.\n\n"
        exit 1
    fi

    printf "\n\n\n**********vSphere Cluster login...*************\n"
    
    export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)


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
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST

            
            rm /root/.kube/config
            rm -R /root/.kube/cache
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
            sed -i 's/kubernetes/'$TKG_VSPHERE_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
            sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config
        fi
    else
        printf "\n\n\nCuurent kubeconfig has not expired. Using the existing one found at .kube/config\n"
        if [ -n "$BASTION_HOST" ]
        then
            printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
        fi
    fi
else
    printf "\n\n\n**********login based on kubeconfig...*************\n"
fi

printf "\n\n\n***********This wizard is now connected to the below cluster...*************\n"
kubectl get ns

if [[ $SILENTMODE == 'y' ]]
then
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    unset confirmed
    isexists=$(kubectl get ns | grep -w jenkins)
    if [[ -z $isexists ]]
    then
        printf "\njenkins namespace not detected.\n "
        while true; do
            read -p "Confirm to install jenkins on k8s? [y/n] " yn
            case $yn in
                [Yy]* ) confirmed='y'; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmed='n'; printf "\n\nYou said no. \n\nExiting...\n\n"; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        if [[ $confirmed == 'y' ]]
        then
            ~/binaries/jenkinsinstall.sh
        fi        
    fi
    
    if [[ $confirmed == 'n' || -z $confirmed ]]
    then
        printf "\nYou can install jenkins at any point by executing the below command:\n"
        printf "/root/binaries/jenkinsinstall.sh"
        printf "\n"
    fi
else
    printf "\n\nStarting Jenkins installation...\n"
    /root/binaries/jenkinsinstall.sh
fi

cd ~

/bin/bash