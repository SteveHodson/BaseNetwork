# Requires 
# cfn-lint (pip install cfn-lint --user)
#
# List of Parameters added from external source

STACK_NAME ?= sh01-vpc-v1
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
	@which cfn-lint | pip install cfn-lint --user
	@cfn-lint $(TEMPLATES)

## create the custom resource asset
build-custom:
	@mkdir ./dist
	@pip3 install netaddr --target ./dist
	@cp custom/calculator.py ./dist
	@cd ./dist && zip -r calculator.zip .

## package up all the assets ready for deployment
package-custom: build-custom
	@aws cloudformation package \
		--template-file ./custom/template.yaml \
		--output-template-file packaged.yaml \
		--s3-bucket $(ASSET_STORAGE)

deploy-custom: package-custom
	@aws cloudformation deploy \
		--template-file packaged.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
		    PipelineName=$(PIPELINE_NAME) \
		--stack-name $(STACK_NAME)
	@aws cloudformation update-termination-protection \
		--stack-name $(STACK_NAME) \
		--enable-termination-protection
	$(MAKE) clean

clean-custom:
	@rm packaged.yaml
	@rm -rf ./dist


delete:
	@aws cloudformation update-termination-protection \
                --stack-name $(STACK_NAME) \
                --no-enable-termination-protection
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)

events:
	@aws cloudformation describe-stack-events --stack-name $(STACK_NAME) 

watch:
	watch --interval 10 "bash -c 'make events | head -25'"
