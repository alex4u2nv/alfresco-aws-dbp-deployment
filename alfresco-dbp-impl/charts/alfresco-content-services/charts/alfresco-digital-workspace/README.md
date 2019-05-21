# Alfresco Digital Workspace (ADW) Helm Chart

Alfresco Digital Workspace (ADW) is an application built using Alfresco Application Development Framework (ADF) components and was generated with Angular CLI.

To use, add the `incubator` to your local Helm.

```sh
helm repo add alfresco-incubator http://kubernetes-charts.alfresco.com/incubator
```

> **Note**: You will be able to deploy this chart on its own only if ADW is accessible from the same origin

## Versioning

The versioning of the Helm Chart is based on [SemVer](https://semver.org/) as it is [supported by Helm](https://docs.helm.sh/developing_charts/#charts-and-versioning).

Stable charts are published in [stable repository](http://kubernetes-charts.alfresco.com/stable).

## To install the ADW cluster

```sh
helm install alfresco-incubator/alfresco-digital-workspace
```

## Introduction

This chart bootstraps an ADW deployment on a [Kubernetes](http://kubernetes.io) cluster
using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.4+ with Beta APIs enabled
- Minimum of 4GB Memory to run ADW along with Alfresco Content Services

## Installing the Chart

To install the chart with the release name `my-adw`:

```sh
helm install --name my-adw alfresco-incubator/alfresco-digital-workspace
```

The command deploys ACS Cluster on the Kubernetes cluster in the default configuration.
The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-adw` deployment:

```sh
helm delete my-adw --purge
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the ADW chart and their default values.

Parameter | Description | Default
| --- | --- | ---
| `ACSURL` | set this value to point the ADW app to an ACS instance deployed on a custom path | n/a |
| `networkpolicysetting` | set this to true if you want to enable network policy for ADW | `false` |