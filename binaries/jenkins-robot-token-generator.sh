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

unset name
unset namespace 
unset kubeconfig 

helpFunction()
{
    printf "\nProvide valid params\n\n"
    echo "Usage: ~/baniries/jenkins-robot-token-generator.sh"
    echo -e "\t-n | --name name of the robot (default jenkins-robot)"
    echo -e "\t-n | --namespace namespace name (required)"
    echo -e "\t-k | --kubeconfig kubeconfig file path (optional)"
    # exit 1 # Exit script after printing help
}

# read the options
TEMP=$(getopt -o "n:s:kh" --long "name:,namespace:,kubeconfig,help" -n $0 -- "$@")
if [ $? != 0 ] ; then echo "Error in command line arguments." >&2 ; returnOrexit ; fi
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -n | --name )
            case "$2" in
                "" ) name=""; shift 2 ;;
                * ) name=$2; shift 2 ;;
            esac ;;
        -s | --namespace )
            case "$2" in
                "" ) namespace=""; shift 2 ;;
                * ) namespace=$2; shift 2 ;;
            esac ;;
        -k | --kubeconfig )
            case "$2" in
                "" ) kubeconfig="~/.kube/config"; shift 2 ;;
                * ) kubeconfig=$2; shift 2 ;;
            esac ;;
        -h | --help ) helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ -z $kubeconfig ]]
then
    kubeconfig="/root/.kube/config"
fi

if [[ -z $name ]]
then
    name="jenkins-robot"
fi

if [[ -z $namespace ]]
then
    printf "\nError: missing namespace name.\n"
    returnOrexit
fi

printf "\nCreating service account $name in namespace $namespace...\n"
kubectl --kubeconfig $kubeconfig -n $namespace create serviceaccount $name
sleep 4

printf "\nMaking jenkins-robot cluster-admin in namespace $namespace...\n"
kubectl --kubeconfig $kubeconfig -n $namespace create rolebinding $name-role-binding --clusterrole=cluster-admin --serviceaccount=$namespace:$name
sleep 4

serviceaccounttokenname=$(kubectl -n $namespace get serviceaccount $name -o go-template --template='{{range .secrets}}{{.name}}{{"\n"}}{{end}}')
serviceaccounttoken=$(kubectl -n $namespace get secrets $serviceaccounttokenname -o go-template --template '{{index .data "token"}}' | base64 -d)

printf "\nJENKINS_ROBOT_SA_TOKEN=$serviceaccounttoken"