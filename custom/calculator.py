'''
A custom resource that calculates the subnet cidr blocks
used when creating a VPC.

Author: Steve Hodson
Date: Jan 2019
'''
import json
import uuid
import logging
import math

from botocore.vendored import requests
from netaddr import IPNetwork

SUCCESS = "SUCCESS"
FAILED = "FAILED"
PHYSICAL_RESOURCE_ID = f"SubnetCidrCalculator-{uuid.uuid1()}"

logger = logging.getLogger()

def handler(event, context):
    '''
    Creates a dictionary of cidr block values to be used by the 
    calling CFN stack.
    '''
    # There is nothing to do for a update/delete request
    if event['RequestType'] != 'Create':
        logger.warn(f"Calling the {context.function_name} when NOT creating a VPC.")
        return send_response(event, context, SUCCESS, 
        reason=f"Calling the {context.function_name} when NOT creating a VPC.")

    # Variables used in this algorithm
    response_data = {}
    properties = event.get("ResourceProperties", {})
    network_cidr = properties["VpcCidrBlock"]
    network_layers = int(properties["NetworkLayers"])
    availability_zones = int(properties["ZonesRequired"])
    
    # get the network address for a given network_cidr
    nw = IPNetwork(network_cidr)
    # check the minimum and maximum prefixes allowed by AWS VPC
    cidr_prefix = nw.prefixlen

    # check the parameters
    params = {
        'cidr_prefix': cidr_prefix,
        'layers': network_layers,
        'availability_zones': availability_zones
        }
    try:
        check_parameters(**params)
    except ValueError as err:
        logger.error(err)
        return send_response(
            event, context, FAILED,
            reason=f"{err.__class__.__name__}: {err}"
            )

    # calculate the VPC Network as the given Network IP may not
    # be the Network IP address as calculated using the hostmask
    network_ip = nw.network
    network = IPNetwork(network_ip)
    network.prefixlen = cidr_prefix
    az_modifier = math.ceil(math.log(availability_zones)/math.log(2))
    
    try:
        for layer_index in range(1,network_layers+1):
            tmp_prefix = cidr_prefix + layer_index
            network_by_layer = list(network.subnet(tmp_prefix))
            network = network_by_layer[1]
            network_by_az = list(network_by_layer[0].subnet(tmp_prefix+az_modifier))
            response_data[f"NetworkLayer{layer_index}"] = str(network_by_layer[0]) + "," + ",".join([str(nw) for nw in network_by_az])
    except Exception as ex:
        logger.error(ex)
        return send_response(
            event, context, FAILED,
            reason=f"{ex.__class__.__name__}: {ex}"
            )

    print(response_data)
    return send_response(event, context, SUCCESS, response_data=response_data)

def check_parameters(**params):
    if (params['cidr_prefix'] < 16 or params['cidr_prefix'] > 28):
        raise ValueError('Illegal prefix number used.  Please use a number between 16 and 28 inclusive')
    if (params['layers'] < 1 or params['layers'] > 4):
        raise ValueError('Illegal number of network layers used.  Please use a list containing between 1 and 4 layers inclusive')
    if (params['availability_zones'] < 1 or params['availability_zones'] > 4):
        raise ValueError('Illegal number of availability zones used.  Please use a number between 1 and 4 inclusive')

def send_response(event, context, response_status, response_data=None, reason=None):
    """This function will wrap a response into a json object and send back to 
    cloudformation for use within the calling stack.
    """
    default_reason = (
        f"See the details in CloudWatch Log group {context.log_group_name} "
        f"Stream: {context.log_stream_name}"
    )

    response_body = json.dumps(
        {
            "Status": response_status,
            "Reason": str(reason) + f".. {default_reason}" if reason else default_reason,
            "PhysicalResourceId": PHYSICAL_RESOURCE_ID,
            "StackId": event["StackId"],
            "RequestId": event["RequestId"],
            "LogicalResourceId": event["LogicalResourceId"],
            "Data": response_data,
        }
    )

    logger.info(f"ResponseURL: {event['ResponseURL']}", )
    logger.info(f"ResponseBody: {response_body}")

    headers = {"Content-Type": "", "Content-Length": str(len(response_body))}

    response = requests.put(event["ResponseURL"], data=response_body, headers=headers)
    try:
        response.raise_for_status()
        logger.info(f"Status code: {response.reason}")
    except requests.HTTPError:
        logger.exception(f"Failed to send CFN response. {response.text}")
        raise
