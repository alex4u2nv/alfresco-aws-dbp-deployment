#!/bin/bash
set -x
# Alfresco Enterprise Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

export PATH=$PATH:/usr/local/bin
export HOME=/root
export KUBECONFIG=/home/ec2-user/.kube/config

usage() {
  echo "$0 <usage>"
  echo " "
  echo "options:"
  echo -e "--help \t Show options for this script"
  echo -e "--helm-command \t helm command"
  echo -e "--alfresco-password \t Alfresco admin password"
  echo -e "--namespace \t Namespace to run helm command in"
  echo -e "--registry-secret \t Base64 dockerconfig.json string to private registry"
}

if [ $# -lt 13 ]; then
  usage
else
  # extract options and their arguments into variables.
  while true; do
      case "$1" in
          -h | --help)
              usage
              exit 1
              ;;
          --release-name)
              RELEASENAME="$2";
              shift 2
              ;;
          --efsname)
              EFSNAME="$2";
              shift 2
              ;;
          --db-endpoint)
              DBENDPOINT="$2";
              shift 2
              ;;
          --db-type)
              DBTYPE="$2";
              shift 2
              ;;
          --acs-db-name)
              ACSDBNAME="$2";
              shift 2
              ;;
          --aps-db-name)
              APSDBNAME="$2";
              shift 2
              ;;
          --aps-db-admin-name)
              APSDBADMINNAME="$2";
              shift 2
              ;;
          --ais-db-name)
              AISDBNAME="$2";
              shift 2
              ;;
          --database-password)
              DATABASEPASSWORD="$2";
              shift 2
              ;;
          --database-username)
              DATABASEUSERNAME="$2";
              shift 2
              ;;
           --activemq-url)
              ACTIVEMQURL="$2";
              shift 2
              ;;
          --activemq-username)
              ACTIVEMQUSERNAME="$2";
              shift 2
              ;;
          --activemq-password)
              ACTIVEMQPASSWORD="$2";
              shift 2
              ;;
          --elastic-search-url)
              ELASTICSEARCHURL="$2";
              shift 2
              ;;
          --alfresco-password)
              ALFRESCO_PASSWORD="$2";
              shift 2
              ;;
          --namespace)
              DESIREDNAMESPACE="$2";
              shift 2
              ;;
          --registry-secret)
              REGISTRYCREDENTIALS="$2";
              shift 2
              ;;
          --external-name)
              EXTERNALNAME="$2";
              shift 2
              ;;
          --acs-s3bucket-name)
              ACSS3BUCKETNAME="$2";
              shift 2
              ;;
          --aps-s3bucket-name)
              APSS3BUCKETNAME="$2";
              shift 2
              ;;
          --aps-s3-access-key)
              APSS3ACCESSKEY="$2";
              shift 2
              ;;
          --aps-s3-secret-key)
              APSS3SECRETKEY="$2";
              shift 2
              ;;
          --s3bucket-location)
              S3BUCKETLOCATION="$2";
              shift 2
              ;;
          --s3bucket-alias)
              S3BUCKETALIAS="$2";
              shift 2
              ;;
          --repo-pods)
              REPO_PODS="$2";
              shift 2
              ;;
          --chart-version)
              CHARTVERSION="$2";
              shift 2
              ;;
          --install)
              INSTALL="true";
              shift
              ;;
          --)
              break
              ;;
          *)
              break
              ;;
      esac
  done


echo "apiVersion: v1
kind: Secret
metadata:
  name: quay-registry-secret
  namespace: $DESIREDNAMESPACE
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $REGISTRYCREDENTIALS" > secret.yaml
kubectl create -f secret.yaml

echo "kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
mountOptions:
  - debug" > storage.yaml
kubectl create -f storage.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# We get Bastion AZ and Region to get a valid right region and query for volumes
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
BASTION_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${BASTION_AZ%?}
# We use this tag below to find the proper EKS cluster name and figure out the unique volume
TAG_NAME="KubernetesCluster"
TAG_VALUE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$TAG_NAME" --region $REGION --output=text | cut -f5)
# EKSname is not unique if we have multiple ACS deployments in the same cluster
# It must be a name unique per Alfresco deployment, not per EKS cluster.
SOLR_VOLUME1_NAME_TAG="$TAG_VALUE-SolrVolume1"
SOLR_VOLUME1_ID=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:Name,Values=$SOLR_VOLUME1_NAME_TAG" --query "Volumes[?State=='available'].{Volume:VolumeId}" --output text)

ALFRESCO_PASSWORD=$(printf %s $ALFRESCO_PASSWORD | iconv -t utf16le | openssl md4| awk '{ print $2}')
echo Adding additional permissions to helm
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
helm repo update

mkdir -p ~/.docker
echo ${REGISTRYCREDENTIALS} | base64 -d > ~/.docker/config.json
ACCOUNT_ID=`aws sts get-caller-identity |jq -r .Account`

region=${REGION}
acs_repo_name=acs-platform
acs_share_name=acs-share
ecr_repository=${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com/${acs_repo_name}
ecr_share=${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com/${acs_share_name}

DBPORT=3306
DBDRIVER="org.mariadb.jdbc.Driver"
DIALECT="org.hibernate.dialect.MySQLDialect"
ACSDBURL="jdbc:mariadb:aurora//${DBENDPOINT}:3306/${ACSDBNAME}?useUnicode=yes&characterEncoding=UTF-8"
APSDBURL="jdbc:mariadb:aurora//${DBENDPOINT}:3306/${APSDBNAME}?useUnicode=yes&characterEncoding=UTF-8"
APSDBADMINURL="jdbc:mariadb:aurora//${DBENDPOINT}:3306/${APSDBADMINNAME}?useUnicode=yes&characterEncoding=UTF-8"

if [ "${DBTYPE}" == "postgresql" ]; then
  DBPORT=5432
  DBDRIVER="org.postgresql.Driver"
  DIALECT="org.hibernate.dialect.PostgreSQLDialect"
  APSDBURL="jdbc:postgresql://${DBENDPOINT}:${DBPORT}/${APSDBNAME}?useUnicode=yes&characterEncoding=UTF-8"
  APSDBADMINURL="jdbc:postgresql://${DBENDPOINT}:${DBPORT}/${APSDBADMINNAME}?useUnicode=yes&characterEncoding=UTF-8"
  ACSDBURL="jdbc:postgresql://${DBENDPOINT}:${DBPORT}/${ACSDBNAME}?useUnicode=yes&characterEncoding=UTF-8"
fi

ACS_LICENSE_NAME=alfresco.lic
ACS_LICENSE_B64=`cat /tmp/Alfresco-ent61*lic |base64 -w0`

if [ "${INSTALL}" = "true" ]; then

echo "apiVersion: v1
kind: Secret
metadata:
  name: ${RELEASENAME}-postgresql-aps
  labels:
    app: ${RELEASENAME}-postgresql-aps
type: Opaque
data:
  postgres-password: ${DATABASEPASSWORD}
" > pg-secret.yaml
kubectl apply -n dbp -f pg-secret.yaml
rm -f pg-secret.yaml

echo "apiVersion: v1
kind: Secret
metadata:
  name: ${RELEASENAME}-acs-license
  labels:
    app: ${RELEASENAME}-acs-license
type: Opaque
data:
    ${ACS_LICENSE_NAME}:  ${ACS_LICENSE_B64}
" > acs-license.yaml
kubectl apply -n dbp -f acs-license.yaml



echo "alfresco-infrastructure:
  persistence:
    efs:
      enabled: true
      dns: \"$EFSNAME\"
  nginx-ingress:
    enabled: false
  alfresco-identity-service:
    keycloak:
      persistence:
        deployPostgres: false
      keycloak:
        persistence:
          deployPostgres: false
          dbVendor: \"postgres\"
          dbName: \"${AISDBNAME}\"
          dbHost: \"${DBENDPOINT}\"
          dbPort: \"${DBPORT}\"
          dbUser: \"${DATABASEUSERNAME}\"
          dbPassword: \"${DATABASEPASSWORD}\"
      client:
        alfresco:
          redirectUris: \"[\\\"https://$EXTERNALNAME*\\\"]\"
keycloak:
  persistence:
    deployPostgres: false
postgresql:
  enabled: false
alfresco-content-services:
  license:
    secretName: acs-license
  networkpolicysetting:
    enabled: false
  messageBroker:
    url: ${ACTIVEMQURL}
    user: ${ACTIVEMQUSERNAME}
    password: \"${ACTIVEMQPASSWORD}\"
  alfresco-infrastructure:
    enabled: false
    activemq:
      enabled: false
  externalHost: \"$EXTERNALNAME\"
  externalProtocol: \"https\"
  externalPort: 443
  registryPullSecrets: \"quay-registry-secret\"
  postgresql:
    enabled: false
    nameOverride: \"postgresql-acs-disabled\"
    replicaCount: 0
  database:
    external: true
    driver: \"${ACSDBDRIVER}\"
    url: \"'${ACSDBURL}'\"
    user: \"${DATABASEUSERNAME}\"
    password: \"${DATABASEPASSWORD}\"
  repository:
    image:
      repository: \"${ecr_repository}\"
      tag: \"latest\"
    replicaCount: $REPO_PODS
    adminPassword: \"$ALFRESCO_PASSWORD\"
    environment:
      IDENTITY_SERVICE_URI: \"https://$EXTERNALNAME/auth\"
    livenessProbe:
      initialDelaySeconds: 420
  persistence:
    repository:
      enabled: false
  s3connector:
    enabled: true
    config:
      bucketName: \"$ACSS3BUCKETNAME\"
      bucketLocation: \"$S3BUCKETLOCATION\"
    secrets:
      encryption: kms
      awsKmsKeyId: \"$S3BUCKETALIAS\"
  transformrouter:
    livenessProbe:
      initialDelaySeconds: 300
  pdfrenderer:
    livenessProbe:
      initialDelaySeconds: 300
  libreoffice:
    livenessProbe:
      initialDelaySeconds: 300
  imagemagick:
    livenessProbe:
      initialDelaySeconds: 300
  share:
    image:
      repository: \"${ecr_share}\"
      tag: \"latest\"
    livenessProbe:
      initialDelaySeconds: 420
  alfresco-search:
    resources:
      requests:
        memory: \"2500Mi\"
      limits:
        memory: \"2500Mi\"
    environment:
      SOLR_JAVA_MEM: \"-Xms2000M -Xmx2000M\"
    persistence:
      VolumeSizeRequest: \"100Gi\"
      EbsPvConfiguration:
        volumeID: \"$SOLR_VOLUME1_ID\"
    affinity: |
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
              - key: \"SolrMasterOnly\"
                operator: In
                values:
                - \"true\"
    tolerations:
    - key: \"SolrMasterOnly\"
      operator: \"Equal\"
      value: \"true\"
      effect: \"NoSchedule\"
    PvNodeAffinity:
      required:
        nodeSelectorTerms:
        - matchExpressions:
          - key: \"SolrMasterOnly\"
            operator: In
            values:
            - \"true\"
alfresco-process-services:
  postgresql:
    enabled: false
  processEngine:
    environment:
      IDENTITY_SERVICE_AUTH: \"https://$EXTERNALNAME/auth/\"
      ACTIVITI_DATASOURCE_URL: \"${APSDBURL}\" 
      ACTIVITI_DATASOURCE_DRIVER: \"${DBDRIVER}\"
      ACTIVITI_HIBERNATE_DIALECT: \"${DIALECT}\"  
      ACTIVITI_DATASOURCE_USERNAME: \"${DATABASEUSERNAME}\"
      ACTIVITI_DATASOURCE_PASSWORD: \"${DATABASEPASSWORD}\"
  adminApp:
    environment:
      ACTIVITI_ADMIN_DATASOURCE_USERNAME: \"${DATABASEUSERNAME}\"
      ACTIVITI_ADMIN_DATASOURCE_PASSWORD: \"${DATABASEPASSWORD}\"
      ACTIVITI_ADMIN_DATASOURCE_DRIVER: \"${DBDRIVER}\"
      ACTIVITI_ADMIN_HIBERNATE_DIALECT: \"${DIALECT}\"
      ACTIVITI_ADMIN_DATASOURCE_URL: \"${APSDBADMINURL}\"
activitiAppProperties:
  datasource.url: \"${APSDBURL}\"
  datasource.username: \"${DATABASEUSERNAME}\"
  datasource.password: \"${DATABASEPASSWORD}\"
  hibernate.dialect: \"${DIALECT}\"
  datasource.driver: \"${DBDRIVER}\"
ldapconfig:
  enabled: true
  url: \"${LDAP_URL}\"
  userSearchBase: \"${LDAP_USER_BASE}\"
  groupSearchBase: \"${LDAP_GROUP_BASE}\"
  user
  principal: \"${LDAP_PRINCIPAL}\"
  credentials: '${LDAP_PASSWORD}'
  groupDifferentialQuery: 
  groupQuery: 
  synchronization:
    full:
      enabled: true
    differential: 
      enabled: true
postgres:
  enabled: false" > dbp_install_values.yaml
ls -l
echo Running Helm Command...
helm install /tmp/alfresco-dbp-impl-0.0.1.tgz -f dbp_install_values.yaml --name $RELEASENAME --namespace $DESIREDNAMESPACE

else
helm upgrade $RELEASENAME /tmp/alfresco-dbp-impl-0.0.1.tgz --version $CHARTVERSION --reuse-values
fi

fi