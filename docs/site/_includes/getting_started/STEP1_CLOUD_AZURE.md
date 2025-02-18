### Preparing environment
You have to create a service account with Microsoft Azure so that Deckhouse can manage cloud resources. The detailed instructions for creating a service account with Microsoft Azure are available in the provider's [documentation](https://cloud.google.com/iam/docs/service-accounts). Below, we will provide a brief overview of the necessary actions:
- Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and perform a `login`;
- Export the environment variable by substituting the Amazon AWS subscription ID instead of the `my-subscription-id`;
  ```shell
export SUBSCRIPTION_ID="my-subscription-id"
```
- Create a service account:
  ```shell
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID" --name "account_name"
```

### Preparing configuration
- Generate an SSH key on the local machine for accessing the cloud-based virtual machines. In Linux and macOS, you can generate a key using the `ssh-keygen` command-line tool. The public key must be included in the configuration file (it will be used for accessing nodes in the cloud).
- Select the layout – the way how resources are located in the cloud *(there are several pre-defined layouts for each provider in Deckhouse)*. Let's use the **Standard** layout in our example for Azure. In this layout:
    - A separate resource group is created for the cluster.
    - By default, one external IP address is dynamically allocated to each instance (it is used for Internet access only). Each IP has 64000 ports available for SNAT. The NAT Gateway (billing) is supported. With it, you can use static public IP addresses for SNAT. Public IP addresses can be assigned to master nodes and nodes created using Terraform. If the master does not have a public IP, an additional instance with a public IP (aka bastion) is required for installation tasks and access to the cluster. In this case, you will also need to configure peering between the cluster's VNet and bastion's VNet. Peering can also be configured between the cluster VNet and other VNets.
- Define the three primary sections with parameters of the prospective cluster in the `config.yml` file:
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
  provider: Azure
  # prefix to differentiate cluster objects (can be used, e.g., in routing)
  prefix: "azure-demo"
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
kind: AzureClusterConfiguration
# pre-defined layout from Deckhouse
layout: Standard
# public SSH key for accessing cloud nodes
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# address space of the cluster virtual network
vNetCIDR: 10.50.0.0/16
# address space of the cluster's nodes
subnetCIDR: 10.50.0.0/24
# parameters of the master node group
masterNodeGroup:
  # number of replicas
  # if more than 1 master node exists, control-plane will be automatically deployed on all master nodes
  replicas: 1
  # parameters of the VM image
  instanceClass:
    # type of the VM
    machineSize: Standard_F4
    # disk size
    diskSizeGb: 32
    # VM image in use
    urn: Canonical:UbuntuServer:18.04-LTS:18.04.202010140
    # enabling assigning external IP addresses to the cluster
    enableExternalIP: true
# Azure access parameters
provider:
  subscriptionId: "***"
  clientId: "***"
  clientSecret: "***"
  tenantId: "***"
  location: "westeurope"
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
  provider: Azure
  # prefix to differentiate cluster objects (can be used, e.g., in routing)
  prefix: "azure-demo"
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
kind: AzureClusterConfiguration
# pre-defined layout from Deckhouse
layout: Standard
# public SSH key for accessing cloud nodes
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# address space of the cluster virtual network
vNetCIDR: 10.50.0.0/16
# address space of the cluster's nodes
subnetCIDR: 10.50.0.0/24
# parameters of the master node group
masterNodeGroup:
  # number of replicas
  # if more than 1 master node exists, control-plane will be automatically deployed on all master nodes
  replicas: 1
  # parameters of the VM image
  instanceClass:
    # type of the VM
    machineSize: Standard_F4
    # disk size
    diskSizeGb: 32
    # VM image in use
    urn: Canonical:UbuntuServer:18.04-LTS:18.04.202010140
    # enabling assigning external IP addresses to the cluster
    enableExternalIP: true
# Azure access parameters
provider:
  subscriptionId: "***"
  clientId: "***"
  clientSecret: "***"
  tenantId: "***"
  location: "westeurope"
```
{% endofftopic %}

Notes:
- The complete list of supported cloud providers and their specific settings is available in the [Cloud providers](/en/documentation/v1/kubernetes.html) section of the documentation.
- To learn more about the Deckhouse release channels, please see the [relevant documentation](/en/documentation/v1/deckhouse-release-channels.html).
