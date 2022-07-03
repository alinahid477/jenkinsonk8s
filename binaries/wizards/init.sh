#!/bin/bash

export $(cat $HOME/.env | xargs)


if [[ ! -f $HOME/binaries/scripts/returnOrexit.sh ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Common Scripts**************\n\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o $HOME/binaries/scripts/download-common-scripts.sh
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
    $HOME/binaries/scripts/download-common-scripts.sh jenkinsk8s scripts
    sleep 1
    if [[ -n $BASTION_HOST ]]
    then
        $HOME/binaries/scripts/download-common-scripts.sh bastion scripts/bastion
        sleep 1
    fi
    printf "\n\n\n///////////// COMPLETED //////////////////\n\n\n"
    printf "\n\n"
fi

printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l $HOME/binaries/wizards/*.sh | awk '{print $9}' | xargs chmod +x
ls -l $HOME/binaries/scripts/*.sh | awk '{print $9}' | xargs chmod +x

## housekeeping
rm /tmp/checkedConnectedK8s > /dev/null 2>&1

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh
source $HOME/binaries/scripts/init-prechecks.sh


if [[ -n $BASTION_HOST ]]
then
    if [[ ! -f  /root/.ssh/id_rsa ]]
    then
        printf "\nERROR: .env file contains bastion host details BUT no id_rsa file exists in .ssh/id_rsa. ...\n"
        exit 1
    fi
    chmod 600 /root/.ssh/id_rsa 
    isrsacommented=$(cat ~/Dockerfile | grep '#\s*COPY .ssh/id_rsa /root/.ssh/')
    if [[ -n $isrsacommented ]]
    then
        printf "\n\nBoth id_rsa file and bastion host input found...\n"
        printf "Adjusting the dockerfile to include id_rsa...\n"
        
        sed -i '/COPY .ssh\/id_rsa \/root\/.ssh\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod 600 \/root\/.ssh\/id_rsa/s/^# //' ~/Dockerfile

        printf "\n\nDockerfile is now adjusted with id_rsa.\n\n"
        printf "\n\nPlease rebuild the docker image and run again (or ./start.sh jenkinsonk8s forcebuild).\n\n"
        exit 1
    fi
fi

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
                ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
                curl -kL https://localhost/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
                sleep 2
                fuser -k 443/tcp
            else 
                curl -kL https://$TKG_VSPHERE_SUPERVISOR_ENDPOINT/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
            fi            
            unzip ~/binaries/vsphere-plugin.zip -d ~/binaries/vsphere-plugin/
            mv ~/binaries/vsphere-plugin/bin/kubectl-vsphere ~/binaries/
            rm -R ~/binaries/vsphere-plugin/
            rm ~/binaries/vsphere-plugin.zip
            
            printf "\n\nkubectl-vsphere is now downloaded in ~/binaries/...\n"
        else
            printf "kubectl-vsphere found in binaries dir...\n"
        fi
        printf "\n\nAdjusting the dockerfile to incluse kubectl-binaries...\n"
        sed -i '/COPY binaries\/kubectl-vsphere \/usr\/local\/bin\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod +x \/usr\/local\/bin\/kubectl-vsphere/s/^# //' ~/Dockerfile

        printf "\n\nDockerfile is now adjusted with kubectl-vsphre.\n\n"
        printf "\n\nPlease rebuild the docker image and run again (or ./start.sh jenkinsonk8s forcebuild).\n\n"
        exit 1
    else
        printf "\nfound kubectl-vsphere...\n"
    fi

    printf "\n\n\n**********vSphere Cluster login...*************\n"
    
    export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_PASSWORD | xargs)


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
        if [[ -z $BASTION_HOST ]]
        then
            rm /root/.kube/config
            rm -R /root/.kube/cache
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server $TKG_VSPHERE_SUPERVISOR_ENDPOINT --insecure-skip-tls-verify -u $TKG_VSPHERE_USERNAME
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
        else
            printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_VSPHERE_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST

            
            rm /root/.kube/config
            rm -R /root/.kube/cache
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_USERNAME
            sed -i 's/kubernetes/'$TKG_VSPHERE_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
            sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config
        fi
    else
        printf "\n\n\nCuurent kubeconfig has not expired. Using the existing one found at .kube/config\n"
        if [[ -n $BASTION_HOST ]]
        then
            printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
        fi
    fi
else
    printf "\n\n\n**********login based on kubeconfig...*************\n"
    if [[ -n $BASTION_HOST ]]
    then
        printf "Bastion host specified...\n"
        sleep 2
        printf "Extracting server url...\n"
        serverurl=$(awk '/server/ {print $NF;exit}' /root/.kube/config | awk -F/ '{print $3}' | awk -F: '{print $1}')
        printf "server url: $serverurl\n"
        printf "Extracting port...\n"
        port=$(awk '/server/ {print $NF;exit}' /root/.kube/config | awk -F/ '{print $3}' | awk -F: '{print $2}')
        if [[ -z $port ]]
        then
            port=80
        fi
        printf "port: $port\n"
        printf "\n\n\n***********Creating K8s endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$serverurl:$port $BASTION_USERNAME@$BASTION_HOST
        sleep 10
    fi
fi


if [[ -n $TMC_API_TOKEN ]]
then
    printf "\nChecking TMC cli...\n"
    ISTMCEXISTS=$(tmc --help)
    sleep 1
    if [ -z "$ISTMCEXISTS" ]
    then
        printf "\n\ntmc command does not exist.\n\n"
        printf "\n\nChecking for binary presence...\n\n"
        IS_TMC_BINARY_EXISTS=$(ls ~/binaries/ | grep tmc)
        sleep 2
        if [ -z "$IS_TMC_BINARY_EXISTS" ]
        then
            printf "\n\nBinary does not exist in ~/binaries directory.\n"
            printf "\nIf you could like to attach the newly created TKG clusters to TMC then please download tmc binary from https://{orgname}.tmc.cloud.vmware.com/clidownload and place in the ~/binaries directory.\n"
            printf "\nAfter you have placed the binary file you can, additionally, uncomment the tmc relevant in the Dockerfile.\n\n"
        else
            printf "\n\nTMC binary found...\n"
            printf "\n\nAdjusting Dockerfile\n"
            sed -i '/COPY binaries\/tmc \/usr\/local\/bin\//s/^# //' ~/Dockerfile
            sed -i '/RUN chmod +x \/usr\/local\/bin\/tmc/s/^# //' ~/Dockerfile
            sleep 2
            printf "\nDONE..\n"
            printf "\n\nPlease build this docker container again and run.\n"
            exit 1
        fi
    else
        printf "\n\ntmc command found.\n\n"
    fi
fi


unset isexists
unset ISTMCEXISTS
unset serverurl

if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
then

    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\nYou confirmed no.\n"; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done    
else
    printf "\n\n\n***********This wizard is now connected to the below cluster...*************\n"
    kubectl get ns

    printf "\n\nStarting Jenkins installation...\n"
    merlin --install-jenkins
fi

printf "\nYou can install, delete and configure jenkins at any point by executing the below wizards:\n"
printf "\tmerlin --install-jenkins\n"
printf "\tmerlin --remove-jenkins\n"
printf "\tmerlin --configure-jenkins\n"

printf "for more: merlin --help\n"

printf "\n\n\n"




cd ~

/bin/bash