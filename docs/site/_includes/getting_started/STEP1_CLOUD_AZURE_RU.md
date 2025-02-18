### Подготовка окружения
Чтобы Deckhouse смог управлять ресурсами в облаке Microsoft Azure, необходимо создать сервисный аккаунт. Подробная инструкция по этому действию доступна в [документации провайдера](https://cloud.google.com/iam/docs/service-accounts). Здесь мы представим краткую последовательность действий, которую необходимо выполнить с помощью консольной утилиты Azure CLI:
- Установите [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) и выполните `login`;
- Экспортируйте переменную окружения, подставив вместо значения `my-subscription-id` идентификатор подписки Amazon AWS:
  ```shell
export SUBSCRIPTION_ID="my-subscription-id"
```
- Создайте service account, выполнив команду:
  ```shell
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID" --name "account_name"
```

### Подготовка конфигурации
- Сгенерируйте на машине-установщике SSH-ключ для доступа к виртуальным машинам в облаке. В Linux и macOS это можно сделать с помощью консольной утилиты `ssh-keygen`. Публичную часть ключа необходимо включить в файл конфигурации: она будет использована для доступа к узлам облака.
- Выберите layout — архитектуру размещения объектов в облаке *(для каждого провайдера есть несколько таких предопределённых layouts в Deckhouse)*. Для примера выберем вариант **Standard**. В данной схеме размещения:
    - Для кластера создаётся отдельная resource group.
    - По умолчанию каждому инстансу динамически выделяется один внешний IP-адрес, который используется только для доступа в интернет. На каждый IP для SNAT доступно 64000 портов. Поддерживается NAT Gateway (тарификация). Позволяет использовать статические публичные IP для SNAT. Публичные IP-адреса можно назначить на master-узлы и узлы, созданные с Terraform. Если master не имеет публичного IP, то для установки и доступа в кластер необходим дополнительный инстанс с публичным IP (aka bastion). В этом случае также потребуется настроить peering между VNet кластера и VNet bastion'а. Между VNet кластера и другими VNet можно настроить peering.
- Задайте минимальные 3 секции параметров для будущего кластера в файле `config.yml`:
{% offtopic title="config.yml для CE" %}
```yaml
# секция с общими параметрами кластера (ClusterConfiguration)
# используемая версия API Deckhouse
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: ClusterConfiguration
# тип инфраструктуры: bare-metal (Static) или облако (Cloud)
clusterType: Cloud
# параметры облачного провайдера
cloud:
  # используемый облачный провайдер
  provider: Azure
  # префикс для объектов кластера для их отличия (используется, например, при маршрутизации)
  prefix: "azure-demo"
# адресное пространство pod’ов кластера
podSubnetCIDR: 10.111.0.0/16
# адресное пространство для service’ов кластера
serviceSubnetCIDR: 10.222.0.0/16
# устанавливаемая версия Kubernetes
kubernetesVersion: "1.19"
# домен кластера (используется для локальной маршрутизации)
clusterDomain: "cluster.local"
---
# секция первичной инициализации кластера Deckhouse (InitConfiguration)
# используемая версия API Deckhouse
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: InitConfiguration
# конфигурация Deckhouse
deckhouse:
  # адрес реестра с образом инсталлятора; указано значение по умолчанию для CE-сборки Deckhouse
  imagesRepo: registry.deckhouse.io/deckhouse/ce
  # строка с параметрами подключения к Docker registry
  registryDockerCfg: eyJhdXRocyI6IHsgInJlZ2lzdHJ5LmRlY2tob3VzZS5pbyI6IHt9fX0=
  # используемый канал обновлений
  releaseChannel: Beta
  configOverrides:
    global:
      # имя кластера; используется, например, в лейблах алертов Prometheus
      clusterName: somecluster
      # имя проекта для кластера; используется для тех же целей
      project: someproject
      modules:
        # шаблон, который будет использоваться для составления адресов системных приложений в кластере
        # например, Grafana для %s.somedomain.com будет доступна на домене grafana.somedomain.com
        publicDomainTemplate: "%s.somedomain.com"
    prometheusMadisonIntegrationEnabled: false
    nginxIngressEnabled: false
---
# секция с параметрами облачного провайдера
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: AzureClusterConfiguration
# layout — архитектура расположения ресурсов в облаке
layout: Standard
# публичная часть SSH-ключа для доступа к узлам облака
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# адресное пространство виртуальной сети кластера
vNetCIDR: 10.50.0.0/16
# адресное пространство подсети кластера
subnetCIDR: 10.50.0.0/24
# параметры группы master-узла
masterNodeGroup:
  # количество реплик мастера
  # если будет больше одного мастер-узла, то control-plane на всех master-узлах будет развернут автоматическии
  replicas: 1
  # параметры используемого образа виртуальной машины
  instanceClass:
    # тип виртуальной машины
    machineSize: Standard_F4
    # размер диска
    diskSizeGb: 32
    # используемый образ виртуальной машины
    urn: Canonical:UbuntuServer:18.04-LTS:18.04.202010140
    # включать ли назначение внешнего IP-адреса для кластера
    enableExternalIP: true
# параметры доступа к облаку Azure
provider:
  subscriptionId: "***"
  clientId: "***"
  clientSecret: "***"
  tenantId: "***"
  location: "westeurope"
```
{% endofftopic %}
{% offtopic title="config.yml для EE" %}
```yaml
# секция с общими параметрами кластера (ClusterConfiguration)
# используемая версия API Deckhouse
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: ClusterConfiguration
# тип инфраструктуры: bare-metal (Static) или облако (Cloud)
clusterType: Cloud
# параметры облачного провайдера
cloud:
  # используемый облачный провайдер
  provider: Azure
  # префикс для объектов кластера для их отличия (используется, например, при маршрутизации)
  prefix: "azure-demo"
# адресное пространство pod’ов кластера
podSubnetCIDR: 10.111.0.0/16
# адресное пространство для service’ов кластера
serviceSubnetCIDR: 10.222.0.0/16
# устанавливаемая версия Kubernetes
kubernetesVersion: "1.19"
# домен кластера (используется для локальной маршрутизации)
clusterDomain: "cluster.local"
---
# секция первичной инициализации кластера Deckhouse (InitConfiguration)
# используемая версия API Deckhouse
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: InitConfiguration
# конфигурация Deckhouse
deckhouse:
  # адрес реестра с образом инсталлятора; указано значение по умолчанию для EE-сборки Deckhouse
  imagesRepo: registry.deckhouse.io/deckhouse/ee
  # строка с ключом для доступа к Docker registry (сгенерировано автоматически для вашего демонстрационного токена)
  registryDockerCfg: <YOUR_ACCESS_STRING_IS_HERE>
  # используемый канал обновлений
  releaseChannel: Beta
  configOverrides:
    global:
      # имя кластера; используется, например, в лейблах алертов Prometheus
      clusterName: somecluster
      # имя проекта для кластера; используется для тех же целей
      project: someproject
      modules:
        # шаблон, который будет использоваться для составления адресов системных приложений в кластере
        # например, Grafana для %s.somedomain.com будет доступна на домене grafana.somedomain.com
        publicDomainTemplate: "%s.somedomain.com"
    prometheusMadisonIntegrationEnabled: false
    nginxIngressEnabled: false
---
# секция с параметрами облачного провайдера
apiVersion: deckhouse.io/v1alpha1
# тип секции конфигурации
kind: AzureClusterConfiguration
# layout — архитектура расположения ресурсов в облаке
layout: Standard
# публичная часть SSH-ключа для доступа к узлам облака
sshPublicKey: ssh-rsa <SSH_PUBLIC_KEY>
# адресное пространство виртуальной сети кластера
vNetCIDR: 10.50.0.0/16
# адресное пространство подсети кластера
subnetCIDR: 10.50.0.0/24
# параметры группы master-узла
masterNodeGroup:
  # количество реплик мастера
  # если будет больше одного мастер-узла, то control-plane на всех master-узлах будет развернут автоматическии
  replicas: 1
  # параметры используемого образа виртуальной машины
  instanceClass:
    # тип виртуальной машины
    machineSize: Standard_F4
    # размер диска
    diskSizeGb: 32
    # используемый образ виртуальной машины
    urn: Canonical:UbuntuServer:18.04-LTS:18.04.202010140
    # включать ли назначение внешнего IP-адреса для кластера
    enableExternalIP: true
# параметры доступа к облаку Azure
provider:
  subscriptionId: "***"
  clientId: "***"
  clientSecret: "***"
  tenantId: "***"
  location: "westeurope"
```
{% endofftopic %}

Примечания:
    - Полный список поддерживаемых облачных провайдеров и настроек для них доступен в секции документации [Cloud providers](/ru/documentation/v1/kubernetes.html).
    - Подробнее о каналах обновления Deckhouse (release channels) можно почитать в [документации](/ru/documentation/v1/deckhouse-release-channels.html).
