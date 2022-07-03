#!/bin/bash

unset COMPLETE

export $(cat $HOME/.env | xargs)

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/scripts/extract-and-take-input.sh

function installJenkins () {

    local confirmation=''
    local isexists=''

    if [[ -n $COMPLETE && $COMPLETE == "YES" ]]
    then
        printf "\n\n\nJenkins deployment is already marked as complete. (If this is not desired please change COMPLETE=\"\" or remove the variable from the .env for new jenkins installation)\n"
        printf "\n\n\nGoing straight to shell access.\n"
        returnOrexit || return 1
    fi


    isexists=$(kubectl get ns | grep -w jenkins)
    if [[ -z $isexists ]]
    then
        printf "\njenkins namespace not detected.\n "
    else
        printf "\n\njenkins namespace detected.\n\n"
        kubectl get ns -n jenkins
    fi

    while true; do
        read -p "Confirm to install jenkins on k8s? [y/n] " yn
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


    local jenkinsInputTemplateFileName='jenkins-install-userinputs.template'

    printf "\n\n\n***********Starting Jenkins installation on this k8s...*************\n\n"


    printf "Collecting k8s storage class information. Below are the storage classes available for this K8s cluster:\n"
    kubectl get storageclass

    
    printf "\nCollect userinput...\n"
    sleep 2
    cp $HOME/binaries/templates/$jenkinsInputTemplateFileName /tmp/
    extractVariableAndTakeInput /tmp/$jenkinsInputTemplateFileName /tmp/doesnotexists || returnOrexit || return 1

    printf "\nReloading environment variables...\n"
    sleep 5
    export $(cat $HOME/.env | xargs)

    if [[ -z $SILENTMODE && -z $JENKINS_PVC_STORAGE_CLASS_NAME ]]
    then
        printf "\n\n\n***********The cluster has below storage policies...*************\n"
        kubectl get storageclass
        printf "\nPlease confirm that you have added value from the above as the value for JENKINS_PVC_STORAGE_CLASS_NAME in the .env file."
        printf "\nIf not, now is the time to do so."
        printf "\nOnce you have added the right value in the .env file confirm y to continue.\n"
        
        confirmation=''
        while true; do
            read -p "Confirm to continue? [y/n] " yn
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
    fi

    if [[ -z $JENKINS_PVC_STORAGE_CLASS_NAME ]]
    then
        printf "\nError: Required JENKINS_PVC_STORAGE_CLASS_NAME is missing from the .env file.\n"
        returnOrexit || return 1
    fi

    printf "\nCreate namespace for Jenkins...."
    kubectl apply -f ~/binaries/templates/kubernetes/global/namespace.yaml
    printf "Done.\n"

    printf "\n\n\n***********Prepare cluster for Jenkins...*************\n"
    printf "\n"

    printf "\nPOD security policy:\n"
    local jenkinspsp=''
    local isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged)
    if [[ -n $isvmwarepsp ]]
    then
        printf "found existing vmware-system-privileged as psp\n"
        jenkinspsp=vmware-system-privileged
    else
        local istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged)
        if [[ -n $istmcpsp ]]
        then
            printf "found existing vmware-system-tmc-privileged as psp\n"
            jenkinspsp=vmware-system-tmc-privileged
        # else
        #     printf "Will create new psp called jenkins-psp-privileged using ~/binaries/templates/kubernetes/global/jenkins-psp.priviledged.yaml\n"
        #     jenkinspsp=jenkins-psp-privileged
            # kubectl apply -f ~/binaries/templates/kubernetes/global/jenkins-psp.priviledged.yaml
        fi
    fi
    if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
    then
        local pspprompter=''
        printf "\nList of available Pod Security Policies:\n"
        kubectl get psp
        if [[ -n $jenkinspsp ]]
        then
            printf "\nSelected existing pod security policy: $jenkinspsp"
            printf "\nPress/Hit enter to accept $jenkinspsp"
            pspprompter=" (selected $jenkinspsp)"  
        else 
            printf "\nHit enter to create a new one"
        fi
        printf "\nOR\nType a name from the available list\n"
        while true; do
            read -p "pod security policy$pspprompter: " inp
            if [[ -z $inp ]]
            then
                if [[ -z $jenkinspsp ]]
                then 
                    printf "\ncreating new psp called jenkins-psp-privileged using ~/binaries/templates/kubernetes/global/jenkins-psp.priviledged.yaml\n"
                    jenkinspsp=jenkins-psp-privileged
                    kubectl apply -f ~/binaries/templates/kubernetes/global/jenkins-psp.priviledged.yaml
                    sleep 2
                    break
                else
                    printf "\nAccepted psp: $jenkinspsp"
                    break
                fi
            else
                local isvalidvalue=$(kubectl get psp | grep -w $inp)
                if [[ -z $isvalidvalue ]]
                then
                    printf "\nYou must provide a valid input.\n"
                else 
                    jenkinspsp=$inp
                    printf "\nAccepted psp: $jenkinspsp"
                    break
                fi
            fi
        done
    fi
    if [[ -n $SILENTMODE && $SILENTMODE == 'y' ]]
    then
        if [[ -z $jenkinspsp ]]
        then
            printf "\ncreating new psp called tbs-psp-privileged using ~/binaries/templates/kubernetes/global/jenkins-psp.priviledged.yaml\n"
            jenkinspsp=jenkins-psp-privileged
            kubectl apply -f ~/binaries/templates/kubernetes/global/tbs-psp.priviledged.yaml
            sleep 2
        fi
    fi
    printf "\n\nusing psp $jenkinspsp to create ClusterRole and ClusterRoleBinding\n"
    awk -v old="POD_SECURITY_POLICY_NAME" -v new="$jenkinspsp" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/kubernetes/global/allow-runasnonroot-clusterrole.yaml > /tmp/allow-runasnonroot-clusterrole.yaml
    kubectl apply -f /tmp/allow-runasnonroot-clusterrole.yaml
    printf "Done.\n"

    printf "\n\ncreating config map for config-as-code plugin\n"
    kubectl apply -f ~/binaries/templates/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml
    printf "Done.\n"

    printf "\nCreate PVC for Jenkins ($JENKINS_PVC_STORAGE_CLASS_NAME):\n"
    awk -v old="JENKINS_PVC_STORAGE_CLASS_NAME" -v new="$JENKINS_PVC_STORAGE_CLASS_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/kubernetes/global/pvc.yaml > /tmp/pvc.yaml
    kubectl apply -f /tmp/pvc.yaml
    printf "Done.\n"

    printf "\nCreate Dockerhub secret: jenkinsdockerhubregkey in kubernetes namespace: jenkins...\n"
    kubectl create secret docker-registry jenkinsdockerhubregkey --docker-server=https://index.docker.io/v2/ --docker-username=$DOCKERHUB_USERNAME --docker-password=$DOCKERHUB_PASSWORD --docker-email=$DOCKERHUB_EMAIL --namespace jenkins
    printf "Done.\n"

    printf "\nCreate Service Account with Dockerhub secret name in kubernetes namespace for Jenkins:\n"
    kubectl -n jenkins apply -f ~/binaries/templates/kubernetes/jenkins/service-account.yaml
    printf "Done.\n"

    printf "\nCreate RBAC for Jenkins:\n"
    kubectl -n jenkins apply -f ~/binaries/templates/kubernetes/jenkins/rbac.yaml
    printf "Done.\n"

    printf "\nVerify get sa and get secret:\n"
    kubectl get sa -n jenkins
    kubectl get secret -n jenkins
    printf "Done.\n"

    printf "\nDeploy Jenkins:\n"
    kubectl apply -f ~/binaries/templates/kubernetes/jenkins/deployment.yaml
    printf "Done.\n"

    sleep 3

    printf "\ncheck replica set status...\n"
    kubectl get rs -n jenkins
    printf "Done.\n"

    printf "\nWait max 2m for pods to be running:\n"
    local count=1
    local podstatus=''
    while true; do
        sleep 10
        podstatus=$(kubectl get pods -n jenkins | grep jenkins- | awk '{print $3}')
        if [[ $podstatus == 'Running' ]]
        then
            kubectl get pods -n jenkins        
            break
        else
            if [[ $count -gt 12 ]]
            then
                printf "\nError: Jenkins pod creation failed. Events are:...\n"
                kubectl get events -n jenkins
                printf "Exiting...\n"
                exit
            fi
            printf ".\n"
            ((count=count+1))
        fi
    done
    printf "Done.\n"


    printf "\nExpose Jenkins through k8s service\n"
    kubectl apply -f ~/binaries/templates/kubernetes/jenkins/service.yaml
    printf "Done.\n"

    printf "\nWait max 2m for svc to have external endpoint:\n"
    count=1
    local issvcsuccessful=''
    local svcstatus=''
    while true; do
        sleep 20
        svcstatus=$(kubectl get svc -n jenkins | grep jenkins | awk '{print $4}')
        if [[ $svcstatus == *"none"* || -z $svcstatus ]]
        then
            if [[ $count -gt 12 ]]
            then
                printf "\nError: Tired of waiting.\nRun the below command to check the status yourself after sometime..\nkubectl get svc -n jenkins\n"
                kubectl get events -n jenkins
                break
            fi
            printf ".\n"
            ((count=count+1))
        else
            issvcsuccessful='y'
            kubectl get svc -n jenkins        
            break
        fi
    done
    printf "Done.\n"

    if [[ -z $issvcsuccessful ]]
    then
        printf "\nError: Jenkins installation partially succeeded."
        printf "\nExtended delay experienced brining service type load balancer online - waiting deadline expired."
        printf "\nYou can take below steps from here:"
        echo -e "\t1. Troubleshoot integrated network service or check some time later if the network is able to assign external ip to jenkins service."
        echo -e "\t2. delete the service kubectl delete -f ~/binaries/templates/kubernetes/jenkins/service.yaml"
        echo -e "\t3. re-creare the service kubectl apply -f ~/binaries/templates/kubernetes/jenkins/service.yaml"
        echo -e "\t4. Run ~/binaries/wizards/jenkinsk8ssetup.sh to complete the configuration of jenkins for running on k8s."
    fi

    if [[ $issvcsuccessful == 'y' ]]
    then
        printf "\nRecording external jenkins access url..\n"
        count=1
        while [[ -z $JENKINS_ENDPOINT && $count -lt 12 ]]; do
            tendpoint=$(kubectl get svc -n jenkins | grep jenkins | awk '{print $4}')
            if [[ ! $tendpoint == \<* ]]
            then
                JENKINS_ENDPOINT=$tendpoint
                break
            else
                printf "Try# $count of max 12: endpoint not available yet. wait 30s...\n"
                sleep 30
            fi
            ((count=count+1))
        done;
        jenkinsurl=$(echo "http://$JENKINS_ENDPOINT")
        printf "\n\n\nYou can now access jenkins by browsing $jenkinsurl"
        printf "\nJENKINS_ENDPOINT=$jenkinsurl" >> $HOME/.env
        printf "\nJENKINS_USERNAME=admin" >> $HOME/.env
    else
        printf "\nJENKINS_USERNAME=" >> $HOME/.env
    fi

    local jenkinspodname=$(kubectl get pods -n jenkins | grep jenkins- | awk '{print $1}')
    local temporarypassword=$(kubectl logs $jenkinspodname -n jenkins | awk '/Please use the following password to proceed to installation/{x=NR+2}(NR == x){print}')
    printf "\nFirst attempt login password is: $temporarypassword"
    printf "\nJENKINS_PASSWORD=$temporarypassword" >> $HOME/.env
    printf "\n"

    printf "\nMarking as complete."
    sed -i '/COMPLETE/d' $HOME/.env
    printf "\nCOMPLETE=YES" >> $HOME/.env

    printf "\n\n"
    printf "*Jenkins deployment complete.*\n\n\n"

    confirmation=''
    if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
    then
        while true; do
            read -p "Would you like to configure jenkins for K8s now [y/n] " yn
            case $yn in
                [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmation='n'; printf "\nYou confirmed no.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
    else
        confirmation='y'
    fi


    if [[ $confirmation == 'y' ]]
    then
        printf "run the below command:\nmerlin --configure-jenkins\n\n"
    else
        printf "\n\nUse ~/binaries/wizards/jenkinsk8ssetup.sh wizard to complete configs for k8s (RECOMMENDED)."
        printf "\nOR\nFollow the instructions further to configure Jenkins for k8s in DETAILS.md follow from here: STEP 5: CONFIGURE JENKINS\n\n\n"
    fi
}