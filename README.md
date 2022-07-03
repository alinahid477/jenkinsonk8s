# Jenkins on k8s quick install (bootstrapped docker)

***This repo is a part of Merlin initiative (https://github.com/alinahid477/merlin)***

<img src="images/logo.png" alt="Jenkins on K8s" width=200 height=210/> 

For details step by step deployment follow [DETAILS.md](DETAILS.md)

This is a bootstrapped docker that will
- Have all necessary components to deploy jenkins on cluster
- a bash script that will deploy jenkins on a k8s cluster
  - the bash script will auto gain access to k8s cluster based on the input on .env file 
  - and deploy jenkins on k8s cluster in a namespace called jenkins (namespace will be created as well).
  - The bash script will do the deployment process only once (the first time it runs it) and mark it as complete (by adding COMPLETE=yes) in the .env file.
  - It will also create and configure necessary plugins for jenkins running on k8s (eg: kubernetes, kubernetes cli, pipeline utility etc plugin configured)
  - It will also create a sample pipeline based on the user input
    - integrating with TBS OR
    - integrating with container registry directly
- After the install and necessary configs the wizard will display default first login url and password

## Prepare

### Local environment
Local machine with docker-ce or docker-ee installed on it.

### .ENV

`mv .env.sample .env`

***If you are using your own kubeconfig file please place the kubeconfig file in .kube/config (`cp /path/to/myown_kubeconfig_file .kube/config`) and ignore the TKG_VSPHERE_ inputs below.***

- BASTION_HOST={(Optional) ip of bastion/jump host. *Leave empty or delete this variable if you are not using bastion/jump host to access k8s cluster*. **Important: If you are using bastion host you must also place a private key file called id_rsa in the .ssh dir (and place the public key file id_rsa.pub in the bastion host's user's .ssh dir. This wizard does not allow password based login for bastion host)**}
- BASTION_USERNAME={(Optional) the username for bastion/jump host. *Leave empty or delete this var if you are not using bastion host*}
- TKG_VSPHERE_SUPERVISOR_ENDPOINT={(Optional) find the supervisor endpoint from vsphere (eg: Menu>Workload management>clusters>Control Plane Node IP Address). *Leave empty or delete this var if the kubernetes cluster is not vsphere with tanzu cluster or you have a kubeconfig file*}
- DOCKERHUB_USERNAME={dockerhub username -- Required to avoid the dockerhub rate limiting issue}
- DOCKERHUB_PASSWORD={dockerhub password -- Required to avoid the dockerhub rate limiting issue}
- DOCKERHUB_EMAIL={provide any email address}
- JENKINS_PVC_STORAGE_CLASS_NAME={Storage class attached to the k8s cluster. Run `kubectl get storageclass` to get a list of storage classes. -- Required}
- TMC_API_TOKEN={*Optional. Only needed if you are using TMC supplied kubeconfig file (and leaving the TKG params empty.)*}
- TKG_VSPHERE_CLUSTER_NAME={(Optional) the vsphere with tanzu k8s cluster name. *Leave empty if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_CLUSTER_ENDPOINT={(Optional) endpoint ip or hostname of the above cluster. Grab it from your vsphere environment. (Menu>Workload Management>Namespaces>Select the namespace where the k8s cluster resides>Compute>VMware Resources>Tanzu Kubernetes Clusters>Control Plane Address[grab the ip of the desired k8s]). *Leave empty or delete this var if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_USERNAME={(Optional) username for accessing the cluster. *Leave empty or delete this var if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_PASSWORD={(Optional) password for accessing the cluster. *Leave empty or delete this var if you are providing your own kubeconfig file in the .kube directory*}


***The below values are needed for creating pipeline in jenkins BUT the user does not need to provide upfront/now. If these values are not present the wizard collect it accordingly.***
- JENKINS_USERNAME=
- JENKINS_PASSWORD=
- JENKINS_SECRET_PVT_REPO_USERNAME=
- JENKINS_SECRET_PVT_REPO_PASSWORD=
- JENKINS_SECRET_PVT_REGISTRY_USERNAME=
- JENKINS_SECRET_PVT_REGISTRY_PASSWORD=
- JENKINS_SECRET_DOCKERHUB_USERNAME=
- JENKINS_SECRET_DOCKERHUB_PASSWORD=
- JENKINS_ROBOT_NAMESPACE=

### Binaries

**Place required binaries in the binaries directory**
- **tmc** (optional) --> required only when you are using tmc supplied kubeconfig

### Kubeconfig (optional)

***If you do not have kubeconfig file and your k8s cluster is a vsphere with tanzu cluster (hence, you have filled all the TKG_VSPHERE_ values in .env file) then skip this section.***

If you are accessing the K8s cluster through a kubeconfig file (and not vSphere sso, meaning you have not filled out the TKG_VSPHERE_ values in the .env file) then
- copy the kubeconfig file and place it in .kube dir (`cp ~/.kube/config .kube/`) of this location.
- ***Make sure the name of the kubeconfig file placed in .kube dir is strictly called **config** (not kubeconfig or no extension)***

### Private key file (optional)

If your k8s cluster api server is in a privated cluster, meaning you cannot access the cluster (eg: `kubectl get ns`) from your local machine directly AND the k8s cluster is only accessible through a jump host aka bastion host
- you must supply a private key file named `id_rsa` in the `.ssh` of this directory for the bastion host
- This bootstrap docker container will create a ssh tunnel using the `id_rsa` private key file for authenticating into the bastion host and create ssh tunnel and use relevent port forward. Thus any kubectl commands can be performed locally but will get executed in the remote k8s cluster.


## Docker build and run

### for linux or mac
```
chmod +x start.sh
./start.sh
```

### for windows
```
start.bat
```
- *Optionally use a 2nd parameter to supply a name for the image and container (eg: `start.sh jenkinsonk8s`). Default name is `jenkinsonk8s` if you do not supply 2nd parameter.*
- *Optionally use a 3rd parameter `forcebuild` to force docker build (eg: `start.sh forecebuild or start.sh jenkinsonk8s forecebuild`). Otherwise if the image exists it will ignore building.*

# That's it

Checkout sample pipeline definition in the sample-java pipeline it will create as part of the deployment. You can save it as Jenkins file for your own pipeline.  