#!/bin/bash

returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

export $(cat /root/.env | xargs)


while [[ -z $JENKINS_USERNAME || -z $JENKINS_PASSWORD ]]; do
    printf "\njenkins username or password not set in the .env file."
    printf "\nPlease add JENKINS_USERNAME={username} and JENKINS_PASSWORD={password} in the .env file"
    printf "\nReplace {username} and {password} with real value you setup in jenkins"
    printf "\n"
    if [[ $SILENTMODE == 'y' ]]
    then
        returnOrexit
    fi
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    export $(cat /root/.env | xargs)
done



printf "\nCreating jenkins secrets for pipeline..\n"

printf "\n1. Source code repository secret..\n"
while [[ -z $JENKINS_SECRET_PVT_REPO_USERNAME || -z $JENKINS_SECRET_PVT_REPO_PASSWORD ]]; do
    printf "\nSource code repo username or password not set in the .env file."
    printf "\nPlease add JENKINS_SECRET_PVT_REPO_USERNAME={username} and JENKINS_SECRET_PVT_REPO_PASSWORD={password} in the .env file"
    printf "\nReplace {username} and {password} with real value you setup in jenkins"
    printf "\n"
    if [[ $SILENTMODE == 'y' ]]
    then
        returnOrexit
    fi
    
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_PVT_REPO_USERNAME)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_PVT_REPO_USERNAME=" >> /root/.env
    fi
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_PVT_REPO_PASSWORD)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_PVT_REPO_PASSWORD=" >> /root/.env
    fi
    
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    export $(cat /root/.env | xargs)
done

printf "\n2. Image registry secret..\n"
while [[ -z $JENKINS_SECRET_PVT_REGISTRY_USERNAME || -z $JENKINS_SECRET_PVT_REGISTRY_PASSWORD ]]; do
    printf "\nSource code repo username or password not set in the .env file."
    printf "\nPlease add JENKINS_SECRET_PVT_REGISTRY_USERNAME={username} and JENKINS_SECRET_PVT_REGISTRY_PASSWORD={password} in the .env file"
    printf "\nReplace {username} and {password} with real value you setup in jenkins"
    printf "\n"
    if [[ $SILENTMODE == 'y' ]]
    then
        returnOrexit
    fi
    
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_PVT_REGISTRY_USERNAME)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_PVT_REGISTRY_USERNAME=" >> /root/.env
    fi
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_PVT_REGISTRY_PASSWORD)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_PVT_REGISTRY_PASSWORD=" >> /root/.env
    fi
    
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    export $(cat /root/.env | xargs)
done

printf "\n3. Dockerhub secret (This is required to avoid ratelimiting error from dockerhub)..\n"
while [[ -z $JENKINS_SECRET_DOCKERHUB_USERNAME || -z $JENKINS_SECRET_DOCKERHUB_PASSWORD ]]; do
    printf "\nSource code repo username or password not set in the .env file."
    printf "\nPlease add JENKINS_SECRET_DOCKERHUB_USERNAME={username} and JENKINS_SECRET_DOCKERHUB_PASSWORD={password} in the .env file"
    printf "\nReplace {username} and {password} with real value you setup in jenkins"
    printf "\n"
    if [[ $SILENTMODE == 'y' ]]
    then
        returnOrexit
    fi
    
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_DOCKERHUB_USERNAME)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_DOCKERHUB_USERNAME=" >> /root/.env
    fi
    isexists=$(cat /root/.env | grep -w JENKINS_SECRET_DOCKERHUB_PASSWORD)
    if [[ -z $isexists ]]
    then
        printf "\nJENKINS_SECRET_DOCKERHUB_PASSWORD=" >> /root/.env
    fi
    
    while true; do
        read -p "Confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    export $(cat /root/.env | xargs)
done



unset jenkinsurl
printf "\nRecording external jenkins access url..\n"
if [[ -z $JENKINS_ENDPOINT ]]
then
    JENKINS_ENDPOINT=$(kubectl get svc -n jenkins | grep jenkins | awk '{print $4}')
fi
jenkinsurl=$(echo "http://$JENKINS_ENDPOINT")
printf "\nJenkins URL: $jenkinsurl\n"

# timeout --foreground -s TERM 3 bash -c \
count=1
while [[ $statusreceived != @(200|403) && $count -lt 12 ]]; do 
    statusreceived=$(curl -s -o /dev/null -L -w ''%{http_code}'' $jenkinsurl)
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

if [[ $statusreceived != @(200|403) ]]
then
    printf "\nExperienced extended delays in accessing $jenkinsurl"
    printf "\nPlease relaunch this wizard once the url browsable."
    returnOrexit
fi

printf "\nDownloading jenkins cli..\n"
curl -o /usr/local/bin/jenkins-cli.jar -L $jenkinsurl/jnlpJars/jenkins-cli.jar
sleep 2
chmod +x /usr/local/bin/jenkins-cli.jar
printf "Done\n"

# printf "\njenkins auth\n"
# java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD -noCertificateCheck

# printf "\nsleep\n"
# sleep 10

awk -v old="JENKINS_ENDPOINT" -v new="$JENKINS_ENDPOINT" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/jenkins-config-as-code-plugin.configmap.yaml > /tmp/jenkins-config-as-code-plugin.configmap.yaml
kubectl apply -f /tmp/jenkins-config-as-code-plugin.configmap.yaml



printf "\ninstalling pugins\n"
# printf "java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-utility-steps kubernetes kubernetes-cli credentials-binding"

java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin credentials
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin credentials-binding
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin cloudbees-folder
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin git
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin workflow-aggregator
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin ssh-slaves
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-stage-view
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-github-lib
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin ws-cleanup
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin build-timeout
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin timestamper
sleep 10

java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin pipeline-utility-steps 
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin kubernetes 
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin kubernetes-cli 
sleep 10
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD install-plugin configuration-as-code
sleep 10

printf "Done.\n"


printf "\nwait 10m\n"
sleep 10m
printf "Done.\n"

printf "\nSafe restart and wait 5min\n"
java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD safe-restart
sleep 5m
printf "Done.\n"

printf "\ncreating credential for pvt-repo..\n"
cp ~/binaries/credential.template ~/kubernetes/jenkins/pvt-repo.credential.xml
sed -i 's/CREDENTIAL_ID/pvt-repo-cred/g' ~/kubernetes/jenkins/pvt-repo.credential.xml
sed -i 's/CREDENTIAL_DESCRIPTION/pvt-repo-cred/g' ~/kubernetes/jenkins/pvt-repo.credential.xml
awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_PVT_REPO_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/pvt-repo.credential.xml > /tmp/pvt-repo.credential.xml
awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_PVT_REPO_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/pvt-repo.credential.xml > ~/kubernetes/jenkins/pvt-repo.credential.xml

java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/pvt-repo.credential.xml
sleep 2
printf "Done.\n"


printf "\ncreating credential file for pvt-registry..\n"
cp ~/binaries/credential.template ~/kubernetes/jenkins/pvt-registry.credential.xml
sed -i 's/CREDENTIAL_ID/pvt-registry-cred/g' ~/kubernetes/jenkins/pvt-registry.credential.xml
sed -i 's/CREDENTIAL_DESCRIPTION/pvt-registry-cred/g' ~/kubernetes/jenkins/pvt-registry.credential.xml
awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_PVT_REGISTRY_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/pvt-registry.credential.xml > /tmp/pvt-registry.credential.xml
awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_PVT_REGISTRY_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/pvt-registry.credential.xml > ~/kubernetes/jenkins/pvt-registry.credential.xml

java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/pvt-registry.credential.xml
sleep 2
printf "Done.\n"


printf "\ncreating credential file for dockerhub..\n"
cp ~/binaries/credential.template ~/kubernetes/jenkins/dockerhub.credential.xml
sed -i 's/CREDENTIAL_ID/dockerhub-cred/g' ~/kubernetes/jenkins/dockerhub.credential.xml
sed -i 's/CREDENTIAL_DESCRIPTION/dockerhub-cred/g' ~/kubernetes/jenkins/dockerhub.credential.xml
awk -v old="CREDENTIAL_USERNAME" -v new="$JENKINS_SECRET_PVT_REGISTRY_USERNAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/kubernetes/jenkins/dockerhub.credential.xml > /tmp/dockerhub.credential.xml
awk -v old="CREDENTIAL_PASSWORD" -v new="$JENKINS_SECRET_PVT_REGISTRY_PASSWORD" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/dockerhub.credential.xml > ~/kubernetes/jenkins/dockerhub.credential.xml

java -jar /usr/local/bin/jenkins-cli.jar -s $jenkinsurl:8080 -auth $JENKINS_USERNAME:$JENKINS_PASSWORD create-credentials-by-xml system::system::jenkins _  < ~/kubernetes/jenkins/dockerhub.credential.xml
sleep 2
printf "Done.\n"