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

if [[ -n $SILENTMODE && $SILENTMODE == 'y' ]]
then
    printf "\n\n\n***********This wizard is now connected to the below cluster...*************\n"
    kubectl get ns

    printf "\n\nStarting Jenkins installation...\n"
    merlin --install-jenkins
else
    printf "\nYou can install, delete and configure jenkins at any point by executing the below wizards:\n"
    printf "\tmerlin --install-jenkins\n"
    printf "\tmerlin --remove-jenkins\n"
    printf "\tmerlin --configure-jenkins\n"

    printf "for more: merlin --help\n"

    printf "\n\n\n"



    cd ~

    /bin/bash
fi