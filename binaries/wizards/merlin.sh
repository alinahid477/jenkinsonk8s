#!/bin/bash

source $HOME/binaries/scripts/returnOrexit.sh
source $HOME/binaries/scripts/color-file.sh

source $HOME/binaries/wizards/jenkinsinstall.sh
source $HOME/binaries/wizards/jenkinsdelete.sh
source $HOME/binaries/wizards/jenkinsk8ssetup.sh


export $(cat $HOME/.env | xargs)

function helpFunction()
{
    printf "\n"
    echo "Usage:"
    echo -e "\t-i | --install-jenkins no paramater needed. Signals the wizard to start the process for installing Jenkins on the K8s cluster."
    echo -e "\t-r | --remove-jenkins no paramater needed. Signals the wizard to start the process for deleting jenkins from the K8s cluster."
    echo -e "\t-c | --configure-jenkins no paramater needed. Signals the wizard to start setting up jenkins on the K8s cluster."
    echo -e "\t-p | --create-pipeline requires type of the pipeline as parameter (supported values: docker/kpack/tbs). Signals the wizard to create jenkins pipeline of the type."
    echo -e "\t-h | --help"
    printf "\n"
}


unset jenkinsInstall
unset jenkinsRemove
unset jenkinsConfigure
unset jenkinsCreatePipeline
unset ishelp

function doCheckK8sOnlyOnce()
{
    if [[ ! -f /tmp/checkedConnectedK8s  ]]
    then
        source $HOME/binaries/scripts/init-checkk8s.sh
        echo "y" >> /tmp/checkedConnectedK8s
    fi
}


function executeCommand()
{
    
    doCheckK8sOnlyOnce

    sleep 3

    if [[ $jenkinsInstall == 'y' ]]
    then
        unset jenkinsInstall
        installJenkins
        returnOrexit || return 1
    fi
    
    if [[ $jenkinsRemove == 'y' ]]
    then
        unset jenkinsRemove
        deleteJenkins   
        returnOrexit || return 1
    fi

    if [[ $jenkinsConfigure == 'y' ]]
    then
        unset jenkinsConfigure
        configureJenkins    
        returnOrexit || return 1
    fi

    if [[ -n $jenkinsCreatePipeline && $jenkinsCreatePipeline != 'X' ]]
    then
        createJenkinsPipeline $jenkinsCreatePipeline
        unset jenkinsCreatePipeline
        returnOrexit || return 1
    else
        printf "\nYou must pass type of the pipeline (supported values: tbs, kpack, docker) as parameter.\n"
        unset jenkinsCreatePipeline
        returnOrexit || return 1
    fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}



output=""

# read the options
TEMP=`getopt -o p:ircf:h --long install-jenkins,create-pipeline:,remove-jenkins,configure-jenkins,file:,help -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -i | --install-jenkins )
            case "$2" in
                "" ) jenkinsInstall='y';  shift 2 ;;
                * ) jenkinsInstall='y' ;  shift 1 ;;
            esac ;;
        -r | --remove-jenkins )
            case "$2" in
                "" ) jenkinsRemove='y'; shift 2 ;;
                * ) jenkinsRemove='y' ; shift 1 ;;
            esac ;;
        -c | --configure-jenkins )
            case "$2" in
                "" ) jenkinsConfigure='y'; shift 2 ;;
                * ) jenkinsConfigure='y' ; shift 1 ;;
            esac ;;
        -p | --create-pipeline )
            case "$2" in
                "" ) jenkinsCreatePipeline='X'; shift 2 ;;
                * ) jenkinsCreatePipeline=$2 ; shift 2 ;;
            esac ;;
        -f | --file )
            case "$2" in
                "" ) argFile=''; shift 2 ;;
                * ) argFile=$2;  shift 2 ;;
            esac ;;
        -h | --help ) ishelp='y'; helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $ishelp != 'y' ]]
then
    executeCommand
fi
unset ishelp