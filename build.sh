#!/bin/sh

#------------------------------------------------------------------------------
# Simple helper script used to build the basic set of network components.
#
# Author: Steve Hodson 
# Date: Jan 2019
# 
# Requires AWSCLI
#
# Usage: ./build.sh project_name
# Parameters:
# Project_Name - name used to label s3 and cfn assets
#
# --parameter-overrides can become unwieldy a feature request to use 
# a params file has been submitted:
# https://github.com/awslabs/serverless-application-model/issues/111 
#------------------------------------------------------------------------------

project=${1:?Please specify a project}
stackname=${project}-network-v1

# check for existence of cfn asset bucket
if aws s3 ls "s3://${stackname}" 2>&1 | grep -q 'NoSuchBucket'
then
aws s3 mb s3://${stackname}
else
echo "Using s3://${stackname} to store assets"
fi

# Package all the assets together
printf "\nPackaging the network templates into the bucket: %s" ${stackname}
aws cloudformation package \
  --template-file build.yaml \
  --s3-bucket ${stackname} \
  --output-template-file package-template.yaml #> /dev/null 2>&1

# Build the VPC
printf "\nDeploying the ${stackname}"
aws cloudformation deploy \
  --template-file package-template.yaml \
  --stack-name ${stackname} \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides $(cat ./build.properties) 

# Clean Up Resources
rm ./package-template.yaml
