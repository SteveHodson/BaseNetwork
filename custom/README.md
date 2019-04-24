# Subnet CIDR Lambda function
This cloudformation custom resource utility lambda function will calculate all the subnet CIDR ranges for a given VPC Cidr range.
## Introduction
Usually VPCs are broken up into subnets whose IP allocation size are equally distributed across the VPC. For instance a VPC whose CIDR block is /21 might have subnets whose IP allocations are all /24. 
Whilst this approach works it does not take into account the functional use of the subnets.  There is another approach that divides the initial IP allocation by a half and recursively divides one of those halves by a half.  This approach will create IP allocation spaces each half the size of the previous.  In my experience a persistence subnet would require less nodes than say the public subnet which itself would require less nodes than a private subnet.
Here an example of a VPC with three layers; note the relative sizes of the boxes refer to the relative sizes of the IP allocations.
![Example VPC](https://github.com/SteveHodson/BaseNetwork/blob/master/custom/Calculator.png "Example VPC")

## Parameters
This function requires the following parameters:
* VpcCidrBlock - a string defining the CIDR block used by the VPC e.g. 10.0.0.0/24
* ZonesRequired - number of availability zones that the VPC will span.
* NetworkLayers - number of functional layers that the VPC will have.

## Output
The output from this function will be a dictionary object containing comma delimited lists of CIDR blocks for each network layer.
```sh
[
  'NetworkLayer1': '<CIDR Block of layer>,<zone1 cidr>,<zone1 cidr>,...',
  'NetworkLayer2': '<CIDR Block of layer>,<zone1 cidr>,<zone1 cidr>,...',
  ...
]
```
For example here is the output from a CIDR calculation for a VPC (VpcCidrBlock=10.0.0.0/16, ZonesRequired=2 and NetworkLayers=2
```sh
{'NetworkLayer1': '10.0.0.0/17,10.0.0.0/18,10.0.64.0/18', 'NetworkLayer2': '10.0.128.0/18,10.0.128.0/19,10.0.160.0/19'}
```
This output is then to be used within your cloudformation subnet creation stacks.
## Use in Cloudformation
This lambda function has been written to extend the functionality of cloudformation in relation to calculating subbnet cidr ranges used in the creation of subnets.  An example written in yaml is shown.
```yaml
CidrBlockCalculation:
    Type: Custom::SubnetCidrCalculator
    Properties:
        ServiceToken: !Sub arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:SubnetCidrCalculator
        VpcCidrBlock: 10.0.0.0/16
        NetworkLayers: 2
        ZonesRequired: 3
```
## Build
```sh
python3 -m env venv
source env/bin/activate
pip install -r requirements
# create a bucket to store assets
make create-store
# build and deply the cidr calculator custom resource
make deploy-custom
```
The installation script expects a unique name that will be used when creating the cloudformation stack.  The choice of creating this separately from the VPC creation is that this utility function can be used for many VPC creation stacks.
This can be tested in the AWS MAnagement Console using the following json:
```javascript
{
  "StackId": "arn:aws:cloudformation:eu-west-1:EXAMPLE/stack-name/guid",
  "ResponseURL": "http://pre-signed-S3-url-for-response",
  "ResourceProperties": {
    "VpcCidrBlock": "10.0.0.0/16",
    "ZonesRequired": "2",
    "NetworkLayers": "2"
  },
  "RequestType": "Create",
  "ResourceType": "Custom::TestResource",
  "RequestId": "unique id for this create request",
  "LogicalResourceId": "MyTestResource"
}
```
Note: Number of zones supported is between 1 and 4 and whilst the solution itself won't break at higher values it will prove wasteful as AWS has at most 4 AZs per region.
## Permissions
The lambda function uses the BasicExecutionRole which accesses CloudWatch only.
## License
Feel free to use this little tool anyway you wish.
