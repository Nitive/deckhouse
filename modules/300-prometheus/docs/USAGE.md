---
title: "The Prometheus monitoring module: usage"
type:
  - instruction
search: prometheus remote write, how to connect to Prometheus, custom Grafana, prometheus remote write
---

## An example of the module configuration

```yaml
prometheus: |
  auth:
    password: xxxxxx
  retentionDays: 7
  storageClass: rbd
  nodeSelector:
    node-role/example: ""
  tolerations:
  - key: dedicated
    operator: Equal
    value: example
```

## Writing Prometheus data to the longterm storage

Prometheus supports remote_write'ing data from the local Prometheus to a separate longterm storage (e.g., [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics)). In Deckhouse, this mechanism is implemented using the `PrometheusRemoteWrite` Custom Resource.

### Example of the basic PrometheusRemoteWrite
```yaml
apiVersion: deckhouse.io/v1
kind: PrometheusRemoteWrite
metadata:
  name: test-remote-write
spec:
  url: https://victoriametrics-test.domain.com/api/v1/write
```

### Example of the expanded PrometheusRemoteWrite
```yaml
apiVersion: deckhouse.io/v1
kind: PrometheusRemoteWrite
metadata:
  name: test-remote-write
spec:
  url: https://victoriametrics-test.domain.com/api/v1/write
  basicAuth:
    username: blahblah
    password: dddddddd
  writeRelabelConfigs:
  - sourceLabels: [__name__]
    action: keep
    regex: prometheus_build_.*
  - sourceLabels: [__name__]
    action: keep
    regex: my_cool_app_metrics_.*
```


## Connecting Prometheus to an external Grafana instance

Each `ingress-nginx-controller` has certificates that can be used to connect to Prometheus. All you need is to create an additional `Ingress` resource.

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: prometheus-api
  namespace: d8-monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_ssl_certificate /etc/nginx/ssl/client.crt;
      proxy_ssl_certificate_key /etc/nginx/ssl/client.key;
      proxy_ssl_protocols TLSv1.2;
      proxy_ssl_session_reuse on;
spec:
  rules:
  - host: prometheus-api.example.com
    http:
      paths:
      - backend:
          serviceName: trickster
          servicePort: https
        path: /trickster/main
  tls:
  - hosts:
    - prometheus-api.example.com
    secretName: example-com-tls
---
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
  namespace: d8-monitoring
type: Opaque
data:
  auth: Zm9vOiRhcHIxJE9GRzNYeWJwJGNrTDBGSERBa29YWUlsSDkuY3lzVDAK  # foo:bar
```
Next, you only need to add the Datasource to Grafana:

**Set `https://prometheus-api.<cluster-domain>/trickster/main/` as the URL**.

<img src="../../images/300-prometheus/prometheus_connect_settings.png" height="500">

* Note that **basic authorization** is not sufficiently secure and safe. You are encouraged to implement additional safety measures, e.g., attach the `nginx.ingress.kubernetes.io/whitelist-source-range` annotation.

* A **considerable disadvantage** of this method is the need to create an Ingress resource in the system namespace.
Deckhouse does **not guarantee** the functionality of this connection method due to its regular updates.

## Connecting an external app to Prometheus

The connection to Prometheus is protected using [kube-rbac-proxy](https://github.com/brancz/kube-rbac-proxy). To connect, you need to create a `ServiceAccount` with the necessary permissions.

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app:prometheus-access
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["prometheuses/http"]
  resourceNames: ["main", "longterm"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app:prometheus-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: app:prometheus-access
subjects:
- kind: ServiceAccount
  name: app
  namespace: default
```
Next, define the following job containing the `curl` request:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: app-curl
  namespace: default
spec:
  template:
    metadata:
      name: app-curl
    spec:
      serviceAccountName: app
      containers:
      - name: app-curl
        image: curlimages/curl:7.69.1
        command: ["sh", "-c"]
        args:
        - >-
          curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k -f
          https://prometheus.d8-monitoring:9090/api/v1/query_range?query=up\&start=1584001500\&end=1584023100\&step=30
      restartPolicy: Never
  backoffLimit: 4
```
The `job` must complete successfully.
