# Jenkins on k8s quick install (bootstrapped docker)

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

***If you are using your own kubeconfig file please place the kubeconfig file in .kube/config (`cp /path/to/myown_kubeconfig_file .kube/config`) and ignore the TKG inputs below.***

- BASTION_HOST={ip of bastion/jump host. Leave blank if you have direct connection}
- BASTION_USERNAME={if the above is present then the username for the above}
- TKG_VSPHERE_SUPERVISOR_ENDPOINT={find the supervisor endpoint from vsphere (eg: Menu>Workload management>clusters>Control Plane Node IP Address). *Leave empty if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_CLUSTER_NAME={the k8s cluster your are trying to access. *Leave empty if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_CLUSTER_ENDPOINT={endpoint ip or hostname of the above cluster. Grab it from your vsphere environment. (Menu>Workload Management>Namespaces>Select the namespace where the k8s cluster resides>Compute>VMware Resources>Tanzu Kubernetes Clusters>Control Plane Address[grab the ip of the desired k8s]). *Leave empty or ignore if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_CLUSTER_USERNAME={username for accessing the cluster. *Leave empty or ignore if you are providing your own kubeconfig file in the .kube directory*}
- TKG_VSPHERE_CLUSTER_PASSWORD={password for accessing the cluster. *Leave empty or ignore if you are providing your own kubeconfig file in the .kube directory*}
- DOCKERHUB_USERNAME={dockerhub username -- needed to avoid the dockerhub rate limiting issue}
- DOCKERHUB_PASSWORD={dockerhub password -- needed to avoid the dockerhub rate limiting issue}
- DOCKERHUB_EMAIL=
- SELFSIGNED_CERT_REGISTRY_URL={pvt registry domain. If you have private registry where jenkins will be pushing docker images to and the registry is using a self-signed cert then you must tell jekins that. *Leave empty or ignore if your private container registry does not uses self signed certificate.*}
- JENKINS_PVC_STORAGE_CLASS_NAME={Storage class attached to the k8s cluster. Run `kubectl get storageclass` to get a list of storage classes.}
- TMC_API_TOKEN={*Optional. Only needed if you are using TMC supplied kubeconfig file (and leaving the TKG params empty.)*}

***The below fields are NOT needed in interactive mode (wizard). You can leave the below empty (or delete it). The wizard will fill it. The below values are needed only if you are using this docker in pipeline to provision jenkins)***
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

## Docker build and run

```
docker build . -t jenkinsonk8s
docker run -it --rm -v ${PWD}:/root/ --add-host kubernetes:127.0.0.1 --name jenkinsonk8s jenkinsonk8s /bin/bash
```

# That's it

**Now Jenkins is good to go with Kubernetes and will scale per job.**

Checkout sample pipeline definition in the sample-java pipeline it will create as part of the deployment. You can save it as Jenkins file for your own pipeline.  