#!/bin/bash

unset JENKINS_USERNAME
unset JENKINS_PASSWORD
unset JENKINS_CONFIG_AS_CODE_CONFIGMAP
unset JENKINS_PLUGINS_INSTALLED
unset JENKINS_SECRETS_APPLIED
unset JENKINS_ENDPOINT
unset JENKINS_SECRET_DOCKERHUB_USERNAME
unset JENKINS_SECRET_DOCKERHUB_PASSWORD
unset JENKINS_SECRET_PVT_REGISTRY_URL
unset JENKINS_SECRET_PVT_REGISTRY_USERNAME
unset JENKINS_SECRET_PVT_REGISTRY_PASSWORD
unset JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT
unset JENKINS_SECRET_PVT_REPO_USERNAME
unset JENKINS_SECRET_PVT_REPO_PASSWORD
unset JENKINS_CONFIG_COMPLETE
unset JENKINS_SAMPLE_PIPELINE_APPLIED

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/scripts/extract-and-take-input.sh

export $(cat $HOME/.env | xargs)


function configureJenkins () {

    local jenkinsInputTemplateFileName='jenkins-config-userinputs.template'
    local confirmation=''
    local isexists=''

    if [[ -n $JENKINS_CONFIG_COMPLETE && $JENKINS_CONFIG_COMPLETE == 'y' ]]
    then
        printf "\n\n\nJenkins config is already marked as complete. (If this is not desired please change JENKINS_CONFIG_COMPLETE=\"\" or remove JENKINS_CONFIG_COMPLETE from the .env file)\n"
        printf "\nQuiting....\n"    
        returnOrexit || return 1
    fi

    printf "\nIf this script get stuck for longer than 7mins (with throwing a java exception) please force quit (cntrl+c few times)\n"
    printf "\nAND run ~/binaries/wizards/jenkinsk8ssetup.sh this wizard again.\n"
    printf "\n(The wizard will start from it left off and avoid re-executing steps)\n"

    printf "\n\n"

    printf "\n******* Starting jenking for k8s config ... *********\n"
    printf "\nthis wizard will\n"
    echo -e "\t1. install all necessary plugins for jenkins processing jobs on k8s."
    echo -e "\t2. configure the plugins accordingly with this environemnt."
    echo -e "\t3. create a sample job."

    printf "\n\n"

    sleep 2

    printf "\nCollect userinput...\n"
    sleep 2
    cp $HOME/binaries/templates/$jenkinsInputTemplateFileName /tmp/
    extractVariableAndTakeInput /tmp/$jenkinsInputTemplateFileName /tmp/doesnotexists || returnOrexit || return 1

    printf "\nReloading environment variables...\n"
    sleep 5
    export $(cat $HOME/.env | xargs)

    confirmation=''
    printf "\nCollencting jenkins server username and password...\n"
    if [[ -n $JENKINS_USERNAME && -n $JENKINS_PASSWORD ]]
    then
        printf "Already present in the .env file\n"
    fi
    while [[ -z $JENKINS_USERNAME || -z $JENKINS_PASSWORD ]]; do
        printf "\njenkins username or password not set in the .env file."
        printf "\nPlease add JENKINS_USERNAME={username} and JENKINS_PASSWORD={password} in the .env file"
        printf "\nReplace {username} and {password} with real value you setup in jenkins"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            printf "\nError: This wizard cannot continue when SILENTMODE='y'.\n"
            returnOrexit || return 1
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_USERNAME)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_USERNAME=" >> $HOME/.env
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_PASSWORD)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_PASSWORD=" >> $HOME/.env
        fi
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
            break;
        fi
        export $(cat $HOME/.env | xargs)
    done
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1
    fi

    confirmation=''
    printf "\nCreating jenkins secrets for pipeline...\n"
    printf "\n1. Source code repository secret...\n"
    if [[ -n $JENKINS_SECRET_PVT_REPO_USERNAME && -n $JENKINS_SECRET_PVT_REPO_PASSWORD ]]
    then
        printf "Already present in the .env file\n"
    fi
    while [[ -z $JENKINS_SECRET_PVT_REPO_USERNAME || -z $JENKINS_SECRET_PVT_REPO_PASSWORD ]]; do
        printf "\nSource code repo username or password not set in the .env file."
        printf "\nPlease add JENKINS_SECRET_PVT_REPO_USERNAME={username} and JENKINS_SECRET_PVT_REPO_PASSWORD={password} in the .env file"
        printf "\nReplace {username} and {password} with real value you setup in jenkins"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            printf "\nError: This wizard cannot continue when SILENTMODE='y'.\n"
            returnOrexit || return 1
        fi
        
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_PVT_REPO_USERNAME)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_PVT_REPO_USERNAME=" >> $HOME/.env
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_PVT_REPO_PASSWORD)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_PVT_REPO_PASSWORD=" >> $HOME/.env
        fi
        
        
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmation='y'; printf "\nYou confirmed no. \n\nQuiting...\n\n"; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        if [[ $confirmation == 'n' ]]
        then
            break;
        fi
        export $(cat $HOME/.env | xargs)
    done
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1;
    fi

    confirmation=''
    printf "\n2a. Image registry secret..\n"
    if [[ -n $JENKINS_SECRET_PVT_REGISTRY_USERNAME && -n $JENKINS_SECRET_PVT_REGISTRY_PASSWORD && -n $JENKINS_SECRET_PVT_REGISTRY_URL ]]
    then
        printf "Already present in the .env file\n"
    fi
    while [[ -z $JENKINS_SECRET_PVT_REGISTRY_USERNAME || -z $JENKINS_SECRET_PVT_REGISTRY_PASSWORD || -z $JENKINS_SECRET_PVT_REGISTRY_URL ]]; do
        printf "\nSource code repo username or password not set in the .env file."
        printf "\nPlease add the below details in the .env file"
        printf "\nJENKINS_SECRET_PVT_REGISTRY_URL={container registry url. For dockerhub the url is same as username}"
        printf "\nJENKINS_SECRET_PVT_REGISTRY_USERNAME={username}"
        printf "\nJENKINS_SECRET_PVT_REGISTRY_PASSWORD={password}"
        printf "\nReplace {} with real value you setup"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            printf "\nError: This wizard cannot continue when SILENTMODE='y'.\n"
            returnOrexit || return 1
        fi
        
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_PVT_REGISTRY_URL)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_PVT_REGISTRY_URL=" >> $HOME/.env
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_PVT_REGISTRY_USERNAME)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_PVT_REGISTRY_USERNAME=" >> $HOME/.env
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_PVT_REGISTRY_PASSWORD)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_PVT_REGISTRY_PASSWORD=" >> $HOME/.env
        fi
        
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) confirmation='n'; printf "\nYou confirmed no.\n"; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        if [[ $confirmation == 'n' ]]
        then
            break;
        fi
        export $(cat $HOME/.env | xargs)
    done
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1;
    fi


    confirmation=''
    printf "\n2b. Collecting information about PVT_REGISTRY_ON_SELF_SIGNED_CERT..\n"
    if [[ -n $JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT ]]
    then
        printf "Already present in the .env file\n"
    fi
    while [[ -z $JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT ]]; do
        while true; do
            read -p "Is your JENKINS_SECRET_PVT_REGISTRY_URL on self signed certificate? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nJENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT=y" >> $HOME/.env; printf "\nyou confirmed yes. Response recorded.\n"; break;;
                [Nn]* ) printf "\nJENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT=n" >> $HOME/.env; printf "\nYou said no. Response recorded.\n"; break;;
                * ) echo "Please answer y or n.";;
            esac
        done
        export $(cat $HOME/.env | xargs)
    done

    if [[ $JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT == 'y' ]]
    then
        printf "\nApplying configmap for self signed cert registry:\n"
        awk -v old="SELFSIGNED_CERT_REGISTRY_URL" -v new="$JENKINS_SECRET_PVT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/kubernetes/jenkins/allow-insecure-registries.yaml > /tmp/allow-insecure-registries.yaml
        kubectl apply -f /tmp/allow-insecure-registries.yaml
        printf "Done.\n"
    fi

    confirmation=''
    printf "\n3. Collecting Dockerhub secret (This is required to avoid ratelimiting error from dockerhub)...\n"
    if [[ -n $JENKINS_SECRET_DOCKERHUB_USERNAME && -n $JENKINS_SECRET_DOCKERHUB_PASSWORD ]]
    then
        printf "Already present in the .env file\n"
    fi
    while [[ -z $JENKINS_SECRET_DOCKERHUB_USERNAME || -z $JENKINS_SECRET_DOCKERHUB_PASSWORD ]]; do
        printf "\nSource code repo username or password not set in the .env file."
        printf "\nPlease add JENKINS_SECRET_DOCKERHUB_USERNAME={username} and JENKINS_SECRET_DOCKERHUB_PASSWORD={password} in the .env file"
        printf "\nReplace {username} and {password} with real value you setup in jenkins"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            printf "\nError: This wizard cannot continue when SILENTMODE='y'.\n"
            returnOrexit || return 1
        fi
        
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_DOCKERHUB_USERNAME)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_DOCKERHUB_USERNAME=" >> $HOME/.env
        fi
        isexists=$(cat $HOME/.env | grep -w JENKINS_SECRET_DOCKERHUB_PASSWORD)
        if [[ -z $isexists ]]
        then
            printf "\nJENKINS_SECRET_DOCKERHUB_PASSWORD=" >> $HOME/.env
        fi
        
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
            break;
        fi
        export $(cat $HOME/.env | xargs)
    done
    if [[ $confirmation == 'n' ]]
    then
        returnOrexit || return 1;
    fi



    local jenkinsurl=''
    if [[ $JENKINS_ENDPOINT == \<* ]]
    then
        unset JENKINS_ENDPOINT
    fi
    
    printf "\nRecording external jenkins access url..\n"
    local count=1
    while [[ -z $JENKINS_ENDPOINT && $count -lt 12 ]]; do
        local tendpoint=$(kubectl get svc -n jenkins | grep jenkins | awk '{print $4}')
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

    if [[ -z $JENKINS_ENDPOINT ]]
    then
        printf "\nError: Jenkins endpoint could not be extracted. Please check if jenkins service is exposed in the jenkins namespace and try again."
        printf "\nQuiting..."
        returnOrexit || return 1
    else
        if [[ $JENKINS_ENDPOINT == *"http"* ]]
        then
            JENKINS_ENDPOINT=$(echo ${JENKINS_ENDPOINT//http:\/\//})
            printf "\nENDPOINT: $JENKINS_ENDPOINT"
        fi
        jenkinsurl=$(echo "http://$JENKINS_ENDPOINT")
        printf "\nJenkins URL: $jenkinsurl\n"
    fi

    if [ -n "$BASTION_HOST" ]
    then
        printf "\n\n\n***********Creating ssh tunnel through bastion $BASTION_USERNAME@$BASTION_HOST on 8080 and 80...*************\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 8080:$JENKINS_ENDPOINT:8080 $BASTION_USERNAME@$BASTION_HOST
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 80:$JENKINS_ENDPOINT:80 $BASTION_USERNAME@$BASTION_HOST
    fi

    count=1
    local statusreceived=''
    while [[ $statusreceived != @(200|403) && $count -lt 12 ]]; do 
        statusreceived=$(curl -s -o /dev/null -L -w ''%{http_code}'' $jenkinsurl/login?from=%2F)
        echo "received status: $statusreceived."
        if [[ $statusreceived != @(200|403) ]]
        then
            echo "Try# $count of max 12: Retrying in 30s..."
            sleep 30
        else
            break
        fi
        ((count=count+1))
    done;

    if [[ $statusreceived != @(200|403) ]]
    then
        printf "\nExperienced extended delays in accessing $jenkinsurl"
        printf "\nPlease relaunch this wizard once the url browsable."
        returnOrexit || return 1
    fi

    isexists=$(ls -l ~/binaries/jenkins-cli.jar)
    if [[ -z $isexists ]]
    then
        printf "\nDownloading jenkins cli..\n"
        curl -o ~/binaries/jenkins-cli.jar -L $jenkinsurl/jnlpJars/jenkins-cli.jar
        sleep 2
        chmod +x ~/binaries/jenkins-cli.jar
        printf "Done\n"
    else
        printf "\nJenkins CLI present in binaries\n"
    fi
    # printf "\njenkins auth\n"
    # java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD -noCertificateCheck

    # printf "\nsleep\n"
    # sleep 10

    if [[ -z $JENKINS_CONFIG_AS_CODE_CONFIGMAP || $JENKINS_CONFIG_AS_CODE_CONFIGMAP == 'n' ]]
    then
        printf "\ncreating config map for config-as-code plugin\n"
        awk -v old="JENKINS_ENDPOINT" -v new="$JENKINS_ENDPOINT" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml > /tmp/jenkins-config-as-code-plugin.configmap.yaml
        kubectl apply -f /tmp/jenkins-config-as-code-plugin.configmap.yaml
        sed -i '/JENKINS_CONFIG_AS_CODE_CONFIGMAP/d' $HOME/.env
        printf "\nJENKINS_CONFIG_AS_CODE_CONFIGMAP=y" >> $HOME/.env
        printf "Done.\n"
    else
        printf "\nJENKINS_CONFIG_AS_CODE_CONFIGMAP marked as complete in .env file. No configmap will be deployed.\n"
    fi


    if [[ -z $JENKINS_PLUGINS_INSTALLED || $JENKINS_PLUGINS_INSTALLED == 'n' ]]
    then
        printf "\ninstalling pugins...\n"
        java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD list-plugins > /tmp/plugins-list.txt
        # printf "java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-utility-steps kubernetes kubernetes-cli credentials-binding"
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^credentials ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin credentials
            sleep 10
        fi
        
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^credentials-binding ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin credentials-binding
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^cloudbees-folder ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin cloudbees-folder
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^git ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin git
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^workflow-cps ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin workflow-cps
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^workflow-aggregator ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin workflow-aggregator
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^ssh-slaves ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin ssh-slaves
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^pipeline-stage-view ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-stage-view
            sleep 10
        fi
        # isexists=$(cat /tmp/plugins-list.txt | grep -w "^pipeline-github-lib ")
        # if [[ -z $isexists ]]
        # then
        #     java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-github-lib
        #     sleep 10
        # fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^ws-cleanup ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin ws-cleanup
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^build-timeout ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin build-timeout
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^timestamper ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin timestamper
            sleep 10
        fi

        isexists=$(cat /tmp/plugins-list.txt | grep -w "^pipeline-utility-steps ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-utility-steps
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^kubernetes ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin kubernetes
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^kubernetes-cli ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin kubernetes-cli
            sleep 10
        fi
        isexists=$(cat /tmp/plugins-list.txt | grep -w "^configuration-as-code ")
        if [[ -z $isexists ]]
        then
            java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin configuration-as-code
            sleep 10
        fi
        printf "Done.\n"


        printf "\nwait 5m\n"
        sleep 5m
        printf "Done.\n"

        printf "\nSafe restart and wait 2min\n"
        java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD safe-restart
        sleep 2m
        
        count=1
        statusreceived=''
        while [[ $statusreceived != @(200|403) && $count -lt 12 ]]; do 
            statusreceived=$(curl -s -o /dev/null -L -w ''%{http_code}'' $jenkinsurl/login?from=%2F)
            echo "received status: $statusreceived."
            if [[ $statusreceived != @(200|403) ]]
            then
                echo "Try# $count of max 12: Retrying in 1min..."
                sleep 1m
            else
                break
            fi
            ((count=count+1))
        done;


        printf "Done.\n"
        sed -i '/JENKINS_PLUGINS_INSTALLED/d' $HOME/.env
        printf "\nJENKINS_PLUGINS_INSTALLED=y" >> $HOME/.env
    else
        printf "\nJENKINS_PLUGINS_INSTALLED is marked as complete. No plugins will be installed.\n"
    fi

    if [[ -z $JENKINS_SECRETS_APPLIED || $JENKINS_SECRETS_APPLIED == 'n' ]]
    then
        count=1
        while [[ $statusreceived != @(200|403) && $count -lt 12 ]]; do 
            statusreceived=$(curl -s -o /dev/null -L -w ''%{http_code}'' $jenkinsurl/login?from=%2F)
            echo "received status: $statusreceived."
            if [[ $statusreceived != @(200|403) ]]
            then
                echo "Retrying in 30s..."
                sleep 30
            else
                break
            fi
            ((count=count+1))
        done;

        printf "\ncreating credential for pvt-repo..\n"
        cp ~/binaries/templates/credential.template ~/kubernetes/jenkins/pvt-repo.credential.xml
        sed -i 's/CREDENTIAL_ID/pvt-repo-cred/g' ~/kubernetes/jenkins/pvt-repo.credential.xml
        sed -i 's/CREDENTIAL_DESCRIPTION/pvt-repo-cred/g' ~/kubernetes/jenkins/pvt-repo.credential.xml
        awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_PVT_REPO_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/pvt-repo.credential.xml > /tmp/pvt-repo.credential.xml
        awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_PVT_REPO_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/pvt-repo.credential.xml > ~/kubernetes/jenkins/pvt-repo.credential.xml
        sleep 2
        java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/pvt-repo.credential.xml
        sleep 2
        printf "Done.\n"


        printf "\ncreating credential file for pvt-registry..\n"
        cp ~/binaries/templates/credential.template ~/kubernetes/jenkins/pvt-registry.credential.xml
        sed -i 's/CREDENTIAL_ID/pvt-registry-cred/g' ~/kubernetes/jenkins/pvt-registry.credential.xml
        sed -i 's/CREDENTIAL_DESCRIPTION/pvt-registry-cred/g' ~/kubernetes/jenkins/pvt-registry.credential.xml
        awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_PVT_REGISTRY_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/pvt-registry.credential.xml > /tmp/pvt-registry.credential.xml
        awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_PVT_REGISTRY_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/pvt-registry.credential.xml > ~/kubernetes/jenkins/pvt-registry.credential.xml
        sleep 2
        java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/pvt-registry.credential.xml
        sleep 2
        printf "Done.\n"

        
        printf "\ncreating credential file for dockerhub..\n"
        cp ~/binaries/templates/credential.template ~/kubernetes/jenkins/dockerhub.credential.xml
        sed -i 's/CREDENTIAL_ID/dockerhub-cred/g' ~/kubernetes/jenkins/dockerhub.credential.xml
        sed -i 's/CREDENTIAL_DESCRIPTION/dockerhub-cred/g' ~/kubernetes/jenkins/dockerhub.credential.xml
        awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_DOCKERHUB_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/dockerhub.credential.xml > /tmp/dockerhub.credential.xml
        awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_DOCKERHUB_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/dockerhub.credential.xml > ~/kubernetes/jenkins/dockerhub.credential.xml
        sleep 2
        java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/dockerhub.credential.xml
        sleep 2
        printf "Done.\n"
        sed -i '/JENKINS_SECRETS_APPLIED/d' $HOME/.env
        printf "\nJENKINS_SECRETS_APPLIED=y" >> $HOME/.env
    else
        printf "\nJENKINS_SECRETS_APPLIED is marked as complete. No credential will be created in jenkins.\n"
    fi


    confirmation=''
    if [[ -z $JENKINS_SAMPLE_PIPELINE_APPLIED || $JENKINS_SAMPLE_PIPELINE_APPLIED == 'n' ]]
    then
        printf "\nWould you like to create a sample pipeline for example? (Highly Recommended)..\n"
        if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
        then        
            while true; do
                read -p "Confirm to continue? [y/n] " yn
                case $yn in
                    [Yy]* ) confirmation='y'; printf "\nyou confirmed yes\n"; break;;
                    [Nn]* ) confirmation='n'; printf "\nYou confirmed no.\nWill not do any action...\n"; break;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        else
            confirmation='y'
        fi

        if [[ $confirmation == 'y' ]]
        then
            if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
            then 
                printf "\nHow would you like to build your container using this sample pipeline?"
                printf "\nType tbs for building using tanzu build service"
                printf "\nOR"
                printf "\nType docker for building using docker build"
                printf "\n\n"
                while true; do
                    read -p "please type one choice ? [tbs/docker] " inp
                    if [[ $inp == "tbs" ]]
                    then
                        containerbuildertype=$inp
                        break;
                    fi
                    
                    if [[ $inp == "docker" ]]
                    then
                        containerbuildertype=$inp
                        break;
                    fi
                    
                    if [[ $containerbuildertype != "tbs" &&  $containerbuildertype != "docker" ]]
                    then
                        printf "\nError: You must provide a valid value\n"
                    fi
                done
            else
                local istbs=$(kubectl get ns | grep -w "^build-service ")
                if [[ -n $istbs ]]
                then
                    containerbuildertype='tbs'
                fi
            fi
            createJenkinsPipeline $containerbuildertype
            ret=$? # 0 means checkCondition was true else 1 meaning check condition is false
            if [[ $ret == 0 ]]
            then
                sed -i '/JENKINS_SAMPLE_PIPELINE_APPLIED/d' $HOME/.env
                printf "\nJENKINS_SAMPLE_PIPELINE_APPLIED=y" >> $HOME/.env
            fi
        fi      
        
    else
        printf "\nJENKINS_SAMPLE_PIPELINE_APPLIED is not marked as complete. No sample pipeline will be created. \n"
    fi

    sed -i '/JENKINS_CONFIG_COMPLETE/d' $HOME/.env
    printf "\nJENKINS_CONFIG_COMPLETE=y" >> $HOME/.env

    printf "\n* Jenkins config for k8s complete. *\n"
    printf "\nPlease login into jenkins via the $jenkinsurl"
    printf "\nusing\n\tusername: $JENKINS_USERNAME\n\tpassword: $JENKINS_PASSWORD"

    printf "\n\nWhen prompted for install plugin please select recommended plugins and proceed as usual.\n"

    printf "\n\n"

}

function createJenkinsPipeline () {

    printf "\n\nCreating pipeline in Jenkins...\n\n"
    local containerbuildertype=$1 #(REQUIRED)
    local jenkinsurl=''
    export $(cat $HOME/.env | xargs)
    sleep 3
    if [[ -z $JENKINS_ENDPOINT || -z $containerbuildertype ]]
    then
        printf "\nError: No Jenkins endpoint in .env or ContainerBuilderType(tbs, docker etc) parameter not supplied."
        printf "\nQuiting..."
        returnOrexit || return 1
    else
        if [[ $JENKINS_ENDPOINT == *"http"* ]]
        then
            jenkinsurl=$(echo "$JENKINS_ENDPOINT")
        else
            jenkinsurl=$(echo "http://$JENKINS_ENDPOINT")
        fi
        printf "\nJenkins URL: $jenkinsurl\n"
    fi

    local containerbuildertype=''
    local clustername=''
    local clusterurl=''
    local jenkinsrobottoken=''
    
    printf "\nsetting up cluster for jenkins-robot..\n"
    clustername=$(kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}' | awk -v i=2 -v j=1 'FNR == i {print $j}')
    clusterurl=$(kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}' | awk -v i=2 -v j=2 'FNR == i {print $j}')
    sleep 2
    jenkinsrobottoken=$(~/binaries/wizards/jenkins-robot-token-generator.sh --name jenkins-robot --namespace default | grep JENKINS_ROBOT_SA_TOKEN | awk -F= '{print $2}')

    printf "\ncreating credential for jenkins-robot..\n"
    cp ~/binaries/templates/credential.secret-text.template /tmp/jenkins-robot.credential.xml
    sed -i 's/CREDENTIAL_ID/jenkins-robot/g' /tmp/jenkins-robot.credential.xml
    awk -v old="CREDENTIAL_PASSWORD" -v new="$jenkinsrobottoken" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/jenkins-robot.credential.xml > ~/kubernetes/jenkins/jenkins-robot.credential.xml
    sleep 1
    java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/jenkins-robot.credential.xml
    sleep 2
    printf "Done.\n"
    
    local pipelinefilename=sample-java-pipeline-$containerbuildertype
    if [[ $JENKINS_SECRET_PVT_REGISTRY_ON_SELF_SIGNED_CERT == 'y' ]]
    then
        pipelinefilename=sample-java-pipeline-sscert-$containerbuildertype
    fi
    awk -v old="K8S_CLUSTER_URL" -v new="$clusterurl" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/templates/$pipelinefilename.template > /tmp/$pipelinefilename.template
    awk -v old="K8S_CLUSTER_NAME" -v new="$clustername" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$pipelinefilename.template > /tmp/$pipelinefilename.xml
    awk -v old="PVT_REGISTRY_URL" -v new="$JENKINS_SECRET_PVT_REGISTRY_URL" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$pipelinefilename.xml > ~/kubernetes/jenkins/$pipelinefilename.nogit.xml
    sleep 1
    printf "\ncreating pipeline...\n"

    java -jar ~/binaries/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-job sample-java-$containerbuildertype < ~/kubernetes/jenkins/$pipelinefilename.nogit.xml
    sleep 2
    printf "Done.\n"

    printf "\nPipeline creation...DONE\n\n"

    return 0
}