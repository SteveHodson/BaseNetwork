# BaseNetwork
This simple solution will create an opinionated VPC with a minimum set of parameters.  The resulting VPC will be 1, 2 or 3 layers and stretched over 1, 2, 3 or 4 availability zones depending on the initial parameters.

I built this as part of a larger automation project involving Service Catalogue and Slack.

## Features
The generic solution creates the following resources:
* VPC with VGW and optional IGW
* Subnets
* Flow Logs (VPC and Subnet variety)
* Route Tables and a route to the IGW if available
* Access Control Lists with very simple allow all traffic rules
* NAT Gateways - one for each defined AZ
* Custom Resource to calculate the subnet cidr ranges

There are three types of network that can be created with this tool; the standard three layer type consisting of a public, private and persistence layers, a simpler two layer consisting of either a public and private or private and persistence layers and finally there is the single layer which can be either a public or private layer.

Public layers will have a single Route Table and an IGW.

The reason for the different types is informed by my own experience of building networks within other companies; some wanted the standard three tier model but others wanted a single facade tier that was publicly facing whilst having a number of private two layer networks joined by either peering or some sort of transit vpc.

## Usage
Firstly you will need to build and deploy the [Lambda custom resource](https://github.com/SteveHodson/BaseNetwork/tree/master/custom/README.md).

Once you have this custom resource installed you can deploy your network as follows:
* Update the `build.properties` as required
* You should have created a bucket to store deployment assets when creating the deploying the lambda function.  Use this or create your own.
* To package and deploy simply use: `make deploy` 

The build process takes approximately 10 minutes and use can create as many as the AWS account can hold.

I have purposively used export-values so that once the basic network has been deploy other layers can be deployed on top without modification of the network repository.  For instance try creating a platform layer consisting of ECS, ALB, RDS and a target group.  Another layer on top of the platform layer would be a ECS service description, security group, and a target group.

By creating these layers you simplify the deployment and maintenance of complex infrastructure solutions.
