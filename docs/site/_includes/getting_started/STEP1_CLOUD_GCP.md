### Preparing environment
You need to create a service account so that Deckhouse can manage resources in the Google Cloud. The detailed instructions for creating a service account are available in the [provider's documentation](https://cloud.google.com/iam/docs/service-accounts). Below is a brief sequence of required actions:

> List of roles required:
> - `roles/compute.admin`
> - `roles/iam.serviceAccountUser`
> - `roles/networkmanagement.admin`

- Export environment variables:
  ```shell
export PROJECT=sandbox
export SERVICE_ACCOUNT_NAME=deckhouse
```
- Select a project:
  ```shell
gcloud config set project $PROJECT
```
- Create a service account:
  ```shell
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME
```
- Verify service account roles:
  ```shell
gcloud projects get-iam-policy ${PROJECT} --flatten="bindings[].members" --format='table(bindings.role)' \
    --filter="bindings.members:${SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"
```
- Create a service account key:
  ```shell
gcloud iam service-accounts keys create --iam-account ${SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com \
    ~/service-account-key-${PROJECT}-${SERVICE_ACCOUNT_NAME}.json
```

### Preparing the configuration
-  Select your layout — the way how resources are located in the cloud *(there are several pre-defined layouts for each provider in Deckhouse)*. For the Google Cloud example, we will use the **Standard** layout. In this layout:
    - A dedicated VPC with Cloud NAT is created for the cluster.
    - Nodes in the cluster have no public IP addresses.
    - Public IP addresses can be assigned to master and static nodes. In this case, One-to-one NAT is used to map the public IP address to the node IP address (note that CloudNAT is not used in this case).
    - You can configure peering between the cluster VPC and other VPCs.

-  Define the three primary sections with parameters of the prospective cluster in the `config.yml` file:
{% offtopic title="config.yml for CE" %}
```yaml
# general cluster parameters (ClusterConfiguration)
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: ClusterConfiguration
# type of the infrastructure: bare-metal (Static) or Cloud (Cloud)
clusterType: Cloud
# cloud provider-related settings
cloud:
  # type of the cloud provider
  provider: GCP
  # prefix to differentiate cluster objects (can be used, e.g., in routing)
  prefix: "google-demo"
# address space of the cluster's pods
podSubnetCIDR: 10.111.0.0/16
# address space of the cluster's services
serviceSubnetCIDR: 10.222.0.0/16
# Kubernetes version to install
kubernetesVersion: "1.19"
# cluster domain (used for local routing)
clusterDomain: "cluster.local"
---
# section for bootstrapping the Deckhouse cluster (InitConfiguration)
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: InitConfiguration
# Deckhouse parameters
deckhouse:
  # address of the registry where the installer image is located; in this case, the default value for Deckhouse CE is set
  imagesRepo: registry.deckhouse.io/deckhouse/ce
  # a special string with parameters to access Docker registry
  registryDockerCfg: eyJhdXRocyI6IHsgInJlZ2lzdHJ5LmRlY2tob3VzZS5pbyI6IHt9fX0=
  # the release channel in use
  releaseChannel: Beta
  configOverrides:
    global:
      # the cluster name (it is used, e.g., in Prometheus alerts' labels)
      clusterName: somecluster
      # the cluster's project name (it is used for the same purpose as the cluster name)
      project: someproject
      modules:
        # template that will be used for system apps domains within the cluster
        # e.g., Grafana for %s.somedomain.com will be available as grafana.somedomain.com
        publicDomainTemplate: "%s.somedomain.com"
    prometheusMadisonIntegrationEnabled: false
    nginxIngressEnabled: false
---
# section containing the parameters of the cloud provider
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: GCPClusterConfiguration
# pre-defined layout from Deckhouse
layout: Standard
# address space of the cluster's nodes
subnetworkCIDR: 10.0.0.0/24
# public SSH key for accessing cloud nodes
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# cluster label used as a prefix to identify it
labels:
  kube: example
# parameters of the master node group
masterNodeGroup:
  # number of replicas
  # if more than 1 master node exists, control-plane will be automatically deployed on all master nodes
  replicas: 1
  # parameters of the VM image
  instanceClass:
    # type of the VM
    machineType: n1-standard-4
    # VM image in use
    image: projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20190911
    # enabling assigning external IP addresses to the cluster
    disableExternalIP: false
# Google Cloud parameters
provider:
  region: europe-west3
  serviceAccountJSON: |
    {
      "type": "service_account",
      "project_id": "somproject-sandbox",
      "private_key_id": "***",
      "private_key": "***",
      "client_email": "mail@somemail.com",
      "client_id": "<client_id>",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/somproject-sandbox.gserviceaccount.com"
    }
```
{% endofftopic %}
{% offtopic title="config.yml for EE" %}
```yaml
# general cluster parameters (ClusterConfiguration)
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: ClusterConfiguration
# type of the infrastructure: bare-metal (Static) or Cloud (Cloud)
clusterType: Cloud
# cloud provider-related settings
cloud:
  # type of the cloud provider
  provider: GCP
  # prefix to differentiate cluster objects (can be used, e.g., in routing)
  prefix: "google-demo"
# address space of the cluster's pods
podSubnetCIDR: 10.111.0.0/16
# address space of the cluster's services
serviceSubnetCIDR: 10.222.0.0/16
# Kubernetes version to install
kubernetesVersion: "1.19"
# cluster domain (used for local routing)
clusterDomain: "cluster.local"
---
# section for bootstrapping the Deckhouse cluster (InitConfiguration)
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: InitConfiguration
# Deckhouse parameters
deckhouse:
  # address of the registry where the installer image is located; in this case, the default value for Deckhouse EE is set
  imagesRepo: registry.deckhouse.io/deckhouse/ee
  # a special string with your token to access Docker registry (generated automatically for your license token)
  registryDockerCfg: <YOUR_ACCESS_STRING_IS_HERE>
  # the release channel in use
  releaseChannel: Beta
  configOverrides:
    global:
      # the cluster name (it is used, e.g., in Prometheus alerts' labels)
      clusterName: somecluster
      # the cluster's project name (it is used for the same purpose as the cluster name)
      project: someproject
      modules:
        # template that will be used for system apps domains within the cluster
        # e.g., Grafana for %s.somedomain.com will be available as grafana.somedomain.com
        publicDomainTemplate: "%s.somedomain.com"
    prometheusMadisonIntegrationEnabled: false
    nginxIngressEnabled: false
---
# section containing the parameters of the cloud provider
# version of the Deckhouse API
apiVersion: deckhouse.io/v1alpha1
# type of the configuration section
kind: GCPClusterConfiguration
# pre-defined layout from Deckhouse
layout: Standard
# address space of the cluster's nodes
subnetworkCIDR: 10.0.0.0/24
# public SSH key for accessing cloud nodes
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# cluster label used as a prefix to identify it
labels:
  kube: example
# parameters of the master node group
masterNodeGroup:
  # number of replicas
  # if more than 1 master node exists, control-plane will be automatically deployed on all master nodes
  replicas: 1
  # parameters of the VM image
  instanceClass:
    # type of the VM
    machineType: n1-standard-4
    # VM image in use
    image: projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20190911
    # enabling assigning external IP addresses to the cluster
    disableExternalIP: false
# Google Cloud parameters
provider:
  region: europe-west3
  serviceAccountJSON: |
    {
      "type": "service_account",
      "project_id": "somproject-sandbox",
      "private_key_id": "***",
      "private_key": "***",
      "client_email": "mail@somemail.com",
      "client_id": "<client_id>",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/somproject-sandbox.gserviceaccount.com"
    }
```
{% endofftopic %}

Notes:
- The complete list of supported cloud providers and their specific settings is available in the [Cloud providers](/en/documentation/v1/kubernetes.html) section of the documentation.
- To learn more about the Deckhouse release channels, please see the [relevant documentation](/en/documentation/v1/deckhouse-release-channels.html).
