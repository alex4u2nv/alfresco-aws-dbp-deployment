#!/bin/bash
chmod +x acs-deployment-aws/uploadHelper.sh alfresco-dbp-deployment/aws/uploadHelper.sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

jq -V &> /dev/null
if [[ $? != 0 ]]; then
	echo "Please install the JQ utility for your system: https://stedolan.github.io/jq/";
	exit;
fi; 
docker &> /dev/null
if [[ $? != 0 ]]; then
	echo "Please install the Docker service for your system: https://www.docker.com/get-started ";
	exit;
fi; 
aws --version &> /dev/null
if [[ $? != 0 ]]; then
	echo "Please install the AWS Client for your system: https://aws.amazon.com/cli/";
	exit;
fi; 

if [[ `find license/  -maxdepth 0 -empty -exec echo empty \;` == "empty" ]]; then 
  echo "Please copy your ACS and APS licenses into the license/ folder"; 
  exit -1
fi
build_bucket=`cat full-deployment-parameters.json |jq '[ .[] | select ( .ParameterKey | contains("TemplateBucketName") ) ]'|jq -r  .[].ParameterValue`
build_prefix=`cat full-deployment-parameters.json |jq '[ .[] | select ( .ParameterKey | contains("TemplateBucketKeyPrefix") ) ]'|jq -r  .[].ParameterValue`

ACCOUNT_ID=`aws sts get-caller-identity |jq -r .Account`

regions=`aws ec2 describe-regions` 
region=""
while [[ "$region" == "" ]]
do
	echo  "Enter a valid region where we're installing the DBP "
	echo $regions | jq -r .Regions[].RegionName
	echo -n "Region: "

	read region
	if [[  ! `echo $regions | grep $region` ]]; then
		region=""
	fi;
done

echo "Uploading custom helm chart"

echo "Region: ${region}"
echo -n "Enter Cloudformation Stack Name: "
read stackname
acs_repo_name=acs-platform
acs_share_name=acs-share
ecr_repository=${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com/${acs_repo_name}
ecr_share=${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com/${acs_share_name}
repositories=`aws ecr describe-repositories`
if [[ ! `echo $repositories | grep $ecr_repository` ]]; then
aws ecr create-repository --repository-name ${acs_repo_name} --region ${region}
fi
if [[ ! `echo $repositories | grep $ecr_share` ]]; then
aws ecr create-repository --repository-name ${acs_share_name} --region ${region}
fi

$(aws ecr get-login --no-include-email --region ${region})

( cd alfresco-dbp-deployment/docker/ags-s3-dbp; docker build -t alfresco/acs-platform:latest -t ${ecr_repository}:latest -f platform.Dockerfile . )
( cd alfresco-dbp-deployment/docker/ags-s3-dbp; docker build -t alfresco/acs-share:latest -t ${ecr_share}:latest -f share.Dockerfile . )
docker push ${ecr_repository}:latest
docker push ${ecr_share}:latest
aws s3 cp alfresco-dbp-impl-0.0.1.tgz s3://${build_bucket}/${build_prefix}/scripts/
aws s3 cp license/ s3://${build_bucket}/${build_prefix}/scripts/ --recursive
( cd  alfresco-dbp-deployment/aws; ./uploadHelper.sh ${build_bucket} ${build_prefix} )

aws cloudformation create-stack \
 --stack-name $stackname \
 --template-body file://alfresco-dbp-deployment/aws/templates/full-deployment.yaml \
 --capabilities CAPABILITY_IAM \
 --parameters `cat full-deployment-parameters.json | jq -c . `
