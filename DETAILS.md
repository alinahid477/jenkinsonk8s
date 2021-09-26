** Read README on calc-devops folder before this one.

UPDATE: SSH Tunnel
===================

***if you have direct access to k8s endpoint (meaning k8s cluster is publicly accessible or accessible through a private network) then ignore this section. If k8s cluster is only accessible using a bastion host then one easy way to interact with the k8s cluster is through ssh tunnel (read more here: https://github.com/alinahid477/VMW/tree/main/tunnel)***

For ssh tunnel purpose below are the files and directory
- Dockerfile (this is a bootstap docker will all necessary utils)
- .kube (this dir is used for tunneling)
- .ssh (this dir is used for tunneling)

### Docker build and run
```
docker build . -t jenkinsk8stunnel -f Dockerfile.DETAILS
docker run -it --rm -v ${PWD}:/root/ --add-host kubernetes:127.0.0.1 --name jenkinsk8stunnel jenkinsk8stunnel /bin/bash
```
This above will
- build docker container
- run and give you shell access to container


Purpose:
===========
This is a documentation explaining how to deploy Jenkins on kubernetes cluster so that:
- Master Jenkins runs on 1 pod.
- When a JOB is submitted (build trigger) Jenkins will spin a new pod for agent to run.

STEP 1: Create cluster and login
=================================

***If your k8s cluster is in a private network and you're accessing through a bastion host then the kubectl apply command in this section needs to be executed directly in the bastion host***

### Transfer the k8s creation file to bastion host
**Ignore this if you are accessing k8s cluster directly or do not want to use ssh tunnel.
File transfer to bastion host:

From your local shell run

`scp -i .ssh/id_rsa kubernetes/jenkins-cluster.yaml ubuntu@10.79.142.40:/home/ubuntu/ali/`


### Create k8s cluster
Provide k8s login password through environment variable

`$ export KUBECTL_VSPHERE_PASSWORD=mysecretpassword`

To create cluster login into vsphere kubernetes using tkg:

`$ kubectl-vsphere login --insecure-skip-tls-verify --server sddc.private.local -u administrator@vsphere.local`

Then, 

`$ kubectl appy -f kubernetes/jenkins-cluster.yaml`

Logout `$ kubectl-vsphere logout`

Go for a coffee. It will take ~10 mins. If it takes less than that then "good for you".


### Without Bastion tunnel
***Skip this if your cluster is in a pvt cloud and you want access/interact with cluster through bastion tunnel.***

After cluster is created login to cluster using:

`$ kubectl vsphere login --tanzu-kubernetes-cluster-name jenkins-cluster --server sddc.private.local --insecure-skip-tls-verify -u administrator@vsphere.local`

Switch to the cluster context

`$ kubectl config use-context jenkins-cluster`


### With Bastion tunnel
***Ignore this if you are accessing k8s cluster directly or do not want to use ssh tunnel.***

from the docker shell run the below commands

`ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:<supervisor cluster endpoint or ip>:443 ubuntu@10.79.142.40`

This will create ssh tunnel for login



Then run

`kubectl vsphere login --tanzu-kubernetes-cluster-name jenkins-cluster --server kubernetes --insecure-skip-tls-verify -u administrator@vsphere.local`

*Since our localhost domain is mapped to a domain called kubernetes and we have created tunnel between localhost and supervisor k8s cluster endpoint we need to use kubernetes instead.*


The above will generate config file in the .kube dir.

Modify the kubeconfig to point to 'kubernetes' instead of 'cluster endpoint or ip'.

in my case the jenkins-cluster ip was: 192.168.220.9
so changed https://192.168.220.9:6443 to https://kubernetes:6443


Finally, run the below command to create ssh tunnel for kubectl

`ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:<k8s/jenkins cluster endpoint or ip>:6443 ubuntu@10.79.142.40`

for example:

in my case: `ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:192.168.220.9:6443 ubuntu@10.79.142.40`



STEP 2: Prepare cluster for Jenkins
===================================

### Create ssh tunnel
**Ignore this if you are accessing k8s cluster directly or do not want to use ssh tunnel.

In the docker container shell run

`ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:192.168.220.9:6443 ubuntu@10.79.142.40`

### Prepare the k8s cluster for Jenkins deployment
**if you are using ssh tunnel then apply these commands in the docker shell.

POD security policy:

`kubectl apply -f kubernetes/global/allow-runasnonroot-clusterrole.yaml`

Create namespace for Jenkins

`kubectl apply -f kubernetes/global/namespace.yaml`

Jenkins needs persistent volume. We already have PV created when we attached storage policy when we created supervisor cluster using the vCentre UI. 

Now all we need to do to give jenkins persistent volume is to create a persistent volume claim.

***Replace the 'storageClassName' with your storage class in the yaml file***

`kubectl apply -f kubernetes/global/pvc.yaml`


STEP 3: ADD SERVICE ACCOUNT
=============================
**if you are using ssh tunnel then apply these commands in the docker shell.


In order for Jenkins to spin new pods per agent (when new job is submitted) it needs access to kubernetes. 
To provide Jenkins with access to kubernetes we will create a service account in the cluster and use that service account in the POD definition in the Jenkins file. (See jenkins file for one of the apps.)


- Create dockerhub regcred

  *Because pods spinned up (for build worker) by Jenkins server will require downloading image (eg: docker-in-docker, maven, jnlp) from docker hub it can run into dockerhub's recently imposed rate limit issue (). To avoid this we can use a dockerhub regcred in the image pull policy. Since the worker/build POD(s) going to use service account anyways lets associate the image regcred to the service account. This way we don't need to remember to add 'imagePullSecret' is POD template in the Jenkins file.*

  `kubectl create secret docker-registry dockerhubregkey --docker-server=https://index.docker.io/v2/ --docker-username=<dockerhub username> --docker-password=<dockerhubpassword> --docker-email=your@email.com --namespace jenkins`

  check id regcred is created:
  ```
  kubectl get secrets dockerhubregkey -n jenkins
  ```
  ***Also notice that this 'dockerhubregkey' is added in the service-account.yaml file***
  *incase of patching existing sa `kubectl patch serviceaccount jenkins-sa -p '{"imagePullSecrets": [{"name": "dockerhubregkey"}]}' -n jenkins`*

- Create service account

  `kubectl -n jenkins apply -f kubernetes/jenkins/service-account.yaml`

- Create role, assing permission to the role, bind role to service account. 

  `kubectl -n jenkins apply -f kubernetes/jenkins/rbac.yaml`

- test/verify:

  ```
  $ kubectl get sa -n jenkins
  $ kubectl get secret -n jenkins
  ```


STEP 4: INSTALL JENKINS
=========================
**if you are using ssh tunnel then apply these commands in the docker shell.

Now that the cluster is ready lets deploy Jenkins on it.

- Integration to Harbor private registry:
  ***skip this section if your container registry is public OR the registry certificate is NOT self-signed. In my case my harbor registry had a self signed certificate, so the deployed Jenkins pod need to trust the registry.***

  ***Replace the registry url in the below yaml file with your own registry url***

  `kubectl apply -f kubernetes/jenkins/allow-insecure-registries.yaml`
   
  **Why?**: Explanation here https://github.com/alinahid477/VMW/tree/main/calcgithub/calc-devops#step-5-integrate-private-container-registry-to-the-cluster
  
  **Where is it going be used**: In the Jenkins pipeline file under Pod Template. This is for pod spinned for jenkins agent to have settings (docker daemon.json) so that it can push to harbor registry.

  
- Deploy Jenkins:
  
  `kubectl apply -f kubernetes/jenkins/deployment.yaml`

  // check replica set status

  `kubectl get rs -n jenkins`

  // check pods status

  `kubectl get pods -n jenkins`

  Wait for the pods to be running before creating the service.

  Notice the below in this file:
  
  - **volumeMounts.mountPath.Name=Jenkins**: This is needed by Jenkins. This is where Jenkins will store its files. Then we have monted this volume to the pvc (persistent volume claim). Without this Jenkins wont run and without PVC in the case of master pods restart/redeployed (happens all time and managed by kubernetes) Jenkins wont be able start with its configured state.
  
  - **volumeMounts.mountPath.Name=Docker-Sock**: In the Jenkins file pod defition (used in apps pipeline) we are using docker in docker. This one is needed for that. Read more at: https://devopscube.com/run-docker-in-docker

- Expose Jenkins:
  Jenkins is now deployed on Kubernetes cluster named "Jenkins-Cluster". However, we still cannot access it. In order to access it we need to expose it through service which will auto create L4 LB.
  
  `kubectl apply -f kubernetes/jenkins/service.yaml`

  // check service status

  `kubectl get svc -n jenkins`

STEP 5: CONFIGURE JENKINS
=========================

When installed first time jenkins is going to locked. Get the 1 off unlock password from logs.

`kubectl logs jenkins-664975b99d-schjz -n jenkins`

Jenkins password: ad156080e16b4a3aa9ea9e64df90df6f

Get the IP for Jenkins:

`kubectl get svc -n jenkins`

// Jenking IP: 192.xxx.xxx.xx


1. Open jenkins using the externalIP address that is received after deploying the jenkins service. On first load Jenkins will prompt in locked mode to with input for password. Input the password you recorded from the log file in STEP 3.
2. Jenkins will prompt for installing plugins. I chose "suggested plugins" option. Jenkins will install these plugins. This should take few seconds.
3. Jenkins will prompt for first user. I entered the details for admin user.
4. Jenkins will prompt for URL. In my case by default the service externalIP was in the url http://<IP ADDRESS>. I used this one.
5. Jenkins is now ready to go. But we still need few more plugins for our CI and CD pipeline.
6. Install additional plugins:
   - For jenkins to work with kubernertes we "Kubernetes Plugin". To install 
     - Go to Manage Jenkins > Manage Plugins > Available (Tab)
     - Search for 'Kubernetes'> Select to Install > Then restart
     
     If for some reason after 5-6 mins you do not see restart automatically happening refresh the page and it will take you to login.

     Login using the user you created.
     
     Go to Manage plugin and check if kubernetes plugin was installed or not.

7. Install Below Additional Plugins:
    - Kubernetes
    - Pipeline Utility Steps
    - Kubernetes CLI

8. Add below Credentials via (Jenkins > Manage Jenkins > Manage Credential > Global > Add Credential):
    - **pvt-repo-cred**: Repository (Github or Bitbucket or whatever your respository is) credential as Username Password type credential
    
    - **dockerhub-cred**: Dockerhub credential as Username Password based. This is needed because of this recent change in Dockerhub :https://www.docker.com/increase-rate-limits.

    - **pvt-registry-cred**: Harbor (My private registry) credential as username password based

    - **jenkins-robot-token**: Kubetoken for K8 SA for K8 deployment of type Secret Text. (See below instruction on how to generate this token). We will use this secret in pipeline. *Note: This service account and token to be created in target cluster, the k8s cluster where you will be deploying your applications. NOT jenkins cluster. If you have deployed Jenkins in the same cluster as your workload cluster then continue in the same cluster other wise switch to the target cluster and create the below. If your target cluster is not ready now you can skip this for now and do this step once there is a target k8s cluster for your workload. If there are multiple k8s cluster then do this in every cluster.*


## Creating K8 Token for deployment using Jenkins


***Note: This service account and token to be created in target cluster, the k8s cluster where you will be deploying your applications. NOT jenkins cluster. If you have deployed Jenkins in the same cluster as your workload cluster then continue in the same cluster other wise switch to the target cluster and create the below. If your target cluster is not ready now you can skip this for now and do this step once there is a target k8s cluster for your workload. If there are multiple k8s cluster then do this in every cluster.***

#### Create a ServiceAccount named `jenkins-robot` in the namespace.


`kubectl -n <namespace eg: calc-k8-cluster> create serviceaccount jenkins-robot`

**OR**

`kubectl apply -f calc-devops/kubernetes/global/jenkins-service-account.yaml`

#### The next line gives `jenkins-robot` administator permissions for this namespace.
*You can make it an admin over all namespaces by creating a `ClusterRoleBinding` instead of a `RoleBinding`.*
*You can also give it different permissions by binding it to a different `(Cluster)Role`.*

`kubectl -n <namespace eg: calc-k8-cluster> create rolebinding jenkins-robot-binding --clusterrole=cluster-admin --serviceaccount=<namespace eg: calc-k8-cluster>:jenkins-robot`

**OR**

`kubectl apply -f calc-devops/kubernetes/global/jenkins-rbac.yaml`

#### Get the name of the token that was automatically generated for the ServiceAccount `jenkins-robot`.

`kubectl -n calculator get serviceaccount jenkins-robot -o go-template --template='{{range .secrets}}{{.name}}{{"\n"}}{{end}}'`

this should output something like this: jenkins-robot-token-9jzfp

#### Retrieve the token and decode it using base64.

`kubectl -n calculator get secrets jenkins-robot-token-9jzfp -o go-template --template '{{index .data "token"}}' | base64 -d`

The namespace here is calculator because that's the namespace where Kubeneter CLI plugin will deploy the workload (not where Jenkins is running). This will output the token. Copy the token and paste it in the secret text of "jenkins-robot-token"



STEP 6: Configure the Kubernetes plugin:
=========================================
- Go to Manage Jenkins > Manage Nodes & Clouds > Configure clouds
- Click: Add new cloud > Select: Kubernetes
- As Jenkins is running on Kubernetes (Namespace: jenkins in this case) I did not need to provide a separate url for it.
- Below conf:
  - After installing kubernetes-plugin for Jenkins
  - Go to Manage Jenkins | Bottom of Page | Cloud | Kubernetes (Add kubenretes cloud)
  - Fill out plugin values
    - **Name**: kubernetes
    - **Kubernetes URL**: 
    - **Kubernetes Namespace**: jenkins
  - Credentials | Add | Jenkins (Choose Kubernetes service account option & Global + Save)
  - Test Connection | Should be successful! If not, check RBAC permissions and fix it!
  - Jenkins URL: http://<Service IP>:8080
  - Tunnel : <Service IP>:50000
- Save

# That's it

**Now Jenkins is good to go with Kubernetes and will scale per job.**



## Handy commands
`grep 'certificate-authority-data' $HOME/.kube/config | awk '{print $2}' | base64 -d | openssl x509 -text`

`kubectl get configmap harbor-allow-insecure-registries -o jsonpath='{.data.daemon\.json}' -n calculator`

`--config core.autocrlf=input` git clone param to avoid git adding an extra CR (^M) character before each LF.