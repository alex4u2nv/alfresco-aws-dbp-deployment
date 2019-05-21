# Alfresco Event Gateway Deployment

*Note*: This is currently a stand alone project but now depends on the Alfresco Infrastructure.

### Kubernetes Cluster

You can choose to deploy the Event Gateway to a local kubernetes cluster or you can choose to deploy to the cloud.
Please check the Anaxes Shipyard documentation on [running a cluster](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).

### Helm Tiller

Initialize the Helm Tiller:
```bash
helm init
```

### Alfresco Infrastructure

Alfresco Infrastructure must be deployed prior to installing the Event Gateway. To install it, follow the [documentation from the Infrastructure project.](https://github.com/Alfresco/alfresco-infrastructure-deployment/blob/master/README.md)

### K8s Cluster Namespace

As mentioned as part of the Anaxes Shipyard guidelines, you should deploy into a separate namespace in the cluster to avoid conflicts (create the namespace only if it does not already exist):
```bash
export DESIREDNAMESPACE=example
kubectl create namespace $DESIREDNAMESPACE
```

This environment variable will be used in the deployment steps.

## Deployment

### 1. Update any dependencies needed from the alfresco-event-gateway chart
```bash
cd helm
helm dep update alfresco-event-gateway
```

### 2. Install the Event Gateway
```bash
helm install alfresco-event-gateway --set messaging.from.activemq.host=$INFRARELEASE-activemq-broker --namespace=$DESIREDNAMESPACE
```
By default, the event gateway will use localhost as the external hostname for references to the hostname of the public ActiveMQ broker. If you are accessing the broker externally from the cluster, you will need to set the messaging.extertnal.host variable. The following is an example
```bash
helm install alfresco-event-gateway --set messaging.from.activemq.host=$INFRARELEASE-activemq-broker --set messaging.external.host=mq.example.alfresco.com --namespace=$DESIREDNAMESPACE
```

### 2. Get the gateway release name from the previous command and set it as a variable:
```bash
export GATEWAYRELEASE=plucky-terp
```

### 3. Wait for the gateway release to get deployed. (When checking status all your pods should be READY 1/1):
```bash
helm status $GATEWAYRELEASE
```

### 4. Teardown:
```bash
helm delete --purge $GATEWAYRELEASE
kubectl delete namespace $DESIREDNAMESPACE
```

For more information on running and tearing down k8s environments, follow this [guide](https://github.com/Alfresco/alfresco-anaxes-shipyard/blob/master/docs/running-a-cluster.md).
