# Requires 
# cfn-lint (pip install cfn-lint --user)
#
# List of Parameters added from external source

STACK_NAME ?= tfs-vpc-v1
ASSET_STORAGE ?= $(STACK_NAME)
AWS_REGION := eu-west-1

TEMPLATES := custom/template.yaml cfn/build.yaml $(wildcard cfn/*/*.yaml)

show: $(wildcard cfn/*/*.yaml)
	@echo $^

## Create asset storage and keep assets for only a day
create-store:
	@aws s3 mb s3://$(ASSET_STORAGE) \
	--region $(AWS_REGION)
	@aws s3api put-bucket-lifecycle-configuration \
	--bucket $(ASSET_STORAGE) \
	--lifecycle-configuration '{"Rules": [{"Expiration": {"Days": 1},"Status": "Enabled","ID":"Temp store for deployable assets","Prefix":""}]}'

## validate all the cfn templates
validate: 
	@which cfn-lint || pip install cfn-lint --user
	@cfn-lint $(TEMPLATES)

## create the custom resource asset
build-custom:
	@mkdir -p ./dist
	@pip install netaddr --target ./dist
	@cp custom/calculator.py ./dist
	@cd ./dist && zip -r calculator.zip .

## package up all the assets ready for deployment
package-custom: build-custom
	@aws cloudformation package \
		--template-file ./custom/template.yaml \
		--output-template-file packaged.yaml \
		--s3-bucket $(ASSET_STORAGE)

## deploy the custom resource
deploy-custom: package-custom
	@aws cloudformation deploy \
		--template-file packaged.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--stack-name $(STACK_NAME)-custom \
		--region $(AWS_REGION)

	@aws cloudformation update-termination-protection \
		--stack-name $(STACK_NAME)-custom \
		--enable-termination-protection
	$(MAKE) clean-custom

## clean up resources associated with the custom resource
clean-custom:
	@rm packaged.yaml
	@rm -rf ./dist

## package up all the network assets ready for deployment
package:
	@aws cloudformation package \
		--template-file ./cfn/build.yaml \
		--output-template-file packaged.yaml \
		--s3-bucket $(ASSET_STORAGE)

## deploy the cfn for building the network
deploy: package
	@aws cloudformation deploy \
		--template-file packaged.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--stack-name $(STACK_NAME) \
		--region $(AWS_REGION) \
		--parameter-overrides $(shell cat build.properties)

	# @aws cloudformation update-termination-protection \
	# 	--stack-name $(STACK_NAME) \
	# 	--enable-termination-protection
	$(MAKE) clean

## clean up resources associated with the network deployment
clean:
	@rm packaged.yaml
	
delete-stack:
	# @aws cloudformation update-termination-protection \
    #             --stack-name $(STACK_NAME) \
    #             --no-enable-termination-protection
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)

events:
	@aws cloudformation describe-stack-events --stack-name $(STACK_NAME) 

watch:
	watch --interval 10 "bash -c 'make events | head -25'"
