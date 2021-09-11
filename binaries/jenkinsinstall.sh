#!/bin/bash
export $(cat /root/.env | xargs)

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

    printf "\n\n\n***********Starting installation of Jenkins...*************\n"


    printf "\nCreate namespace for Jenkins:\n"
    kubectl apply -f ~/kubernetes/global/namespace.yaml
    printf "Done.\n"

    printf "\n\n\n***********Prepare cluster for Jenkins...*************\n"
    printf "\n"

    printf "\nPOD security policy:\n"
    unset jenkinspsp
    isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged)
    if [[ -n $isvmwarepsp ]]
    then
        printf "found existing vmware-system-privileged as psp\n"
        jenkinspsp=vmware-system-privileged
    else
        istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged)
        if [[ -n $istmcpsp ]]
        then
            printf "found existing vmware-system-tmc-privileged as psp\n"
            jenkinspsp=vmware-system-tmc-privileged
        else
            printf "creating new psp called jenkins-psp-privileged using ~/kubernetes/global/jenkins-psp.priviledged.yaml\n"
            jenkinspsp=jenkins-psp-privileged
            kubectl apply -f ~/kubernetes/global/jenkins-psp.priviledged.yaml
        fi
    fi
    if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
    then
        unset pspprompter
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
                    printf "\ncreating new psp called jenkins-psp-privileged using ~/kubernetes/global/jenkins-psp.priviledged.yaml\n"
                    jenkinspsp=jenkins-psp-privileged
                    kubectl apply -f ~/kubernetes/global/jenkins-psp.priviledged.yaml
                    sleep 2
                    break
                else
                    printf "\nAccepted psp: $jenkinspsp"
                    break
                fi
            else
                isvalidvalue=$(kubectl get psp | grep -w $inp)
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
    
    printf "\n\nusing psp $jenkinspsp to create ClusterRole and ClusterRoleBinding\n"
    awk -v old="POD_SECURITY_POLICY_NAME" -v new="$jenkinspsp" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/global/allow-runasnonroot-clusterrole.yaml > /tmp/allow-runasnonroot-clusterrole.yaml
    kubectl apply -f /tmp/allow-runasnonroot-clusterrole.yaml
    printf "Done.\n"

    printf "\n\ncreating config map for config-as-code plugin\n"
    kubectl apply -f ~/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml
    printf "Done.\n"

    printf "\nCreate PVC for Jenkins ($JENKINS_PVC_STORAGE_CLASS_NAME):\n"
    awk -v old="JENKINS_PVC_STORAGE_CLASS_NAME" -v new="$JENKINS_PVC_STORAGE_CLASS_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/global/pvc.yaml > /tmp/pvc.yaml
    kubectl apply -f /tmp/pvc.yaml
    printf "Done.\n"

    printf "\nCreate Dockerhub secret in kubernetes namespace for Jenkins:\n"
    kubectl create secret docker-registry dockerhubregkey --docker-server=https://index.docker.io/v2/ --docker-username=$DOCKERHUB_USERNAME --docker-password=$DOCKERHUB_PASSWORD --docker-email=$DOCKERHUB_EMAIL --namespace jenkins
    printf "Done.\n"

    printf "\nCreate Service Account with Dockerhub secret name in kubernetes namespace for Jenkins:\n"
    kubectl -n jenkins apply -f ~/kubernetes/jenkins/service-account.yaml
    printf "Done.\n"

    printf "\nCreate RBAC for Jenkins:\n"
    kubectl -n jenkins apply -f ~/kubernetes/jenkins/rbac.yaml
    printf "Done.\n"

    printf "\nVerify get sa and get secret:\n"
    kubectl get sa -n jenkins
    kubectl get secret -n jenkins
    printf "Done.\n"

    if [[ -n  $SELFSIGNED_CERT_REGISTRY_URL ]]
    then
        printf "\nIntegration to Harbor private registry:\n"
        awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$SELFSIGNED_CERT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
        kubectl apply -f /tmp/allow-insecure-registries.yaml
        printf "Done.\n"
    fi
    

    printf "\nDeploy Jenkins:\n"
    kubectl apply -f ~/kubernetes/jenkins/deployment.yaml
    printf "Done.\n"

    sleep 3

    printf "\ncheck replica set status...\n"
    kubectl get rs -n jenkins
    printf "Done.\n"

    printf "\nWait max 2m for pods to be running:\n"
    count=1
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
    kubectl apply -f ~/kubernetes/jenkins/service.yaml
    printf "Done.\n"

    printf "\nWait max 2m for svc to have external endpoint:\n"
    count=1
    unset issvcsuccessful
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
        echo -e "\t2. delete the service kubectl delete -f ~/kubernetes/jenkins/service.yaml"
        echo -e "\t3. re-creare the service kubectl apply -f ~/kubernetes/jenkins/service.yaml"
        echo -e "\t4. Run ~/binaries/jenkinsk8ssetup.sh to complete the configuration of jenkins for running on k8s."
    fi

    if [[ $issvcsuccessful == 'y' ]]
    then
        jenkinsurl=$(kubectl get svc -n jenkins | grep jenkins | awk '{print $4}')
        printf "\nYou can now access jenkins by browsing http://$jenkinsurl"
        printf "\nJENKINS_ENDPOINT=$jenkinsurl" >> /root/.env
        printf "\nJENKINS_USERNAME=admin" >> /root/.env
    else
        printf "\nJENKINS_USERNAME=" >> /root/.env
    fi

    jenkinspodname=$(kubectl get pods -n jenkins | grep jenkins- | awk '{print $1}')
    temporarypassword=$(kubectl logs $jenkinspodname -n jenkins | awk '/Please use the following password to proceed to installation/{x=NR+2}(NR == x){print}')
    printf "\nFirst attempt login password is: $temporarypassword"
    printf "\nJENKINS_PASSWORD=$temporarypassword" >> /root/.env
    printf "\n"

    printf "\nMarking as complete."
    printf "\nCOMPLETE=YES" >> /root/.env

    printf "\n\n"
    printf "*Jenkins deployment complete.*\n"

    unset confirmed
    if [[ -z $SILENTMODE || $SILENTMODE == 'n']]
    then
        while true; do
            read -p "Confirm to config jenkins configs for k8s [y/n] " yn
            case $yn in
                [Yy]* ) confirmed='y'; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nReturning...\n\n"; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        confirmed='y'
    fi


    if [[ $confirmed == 'y' ]]
    then
        source ~/binaries/jenkinsk8ssetup.sh
    else
        printf "\n\nUse ~/binaries/jenkinsk8ssetup.sh wizard to complete configs for k8s"
        printf "\nOR\nFollow the instructions further to configure Jenkins for k8s in Readme.md follow from here: STEP 5: CONFIGURE JENKINS\n\n\n"
    fi
    
    
else
    printf "\n\n\nJenkins deployment is already marked as complete. (If this is not desired please change COMPLETE=\"\" or remove COMPLETE in the .env for new jenkins installation)\n"
    printf "\n\n\nGoing straight to shell access.\n"
fi
