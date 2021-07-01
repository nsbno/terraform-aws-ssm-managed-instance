#!/usr/bin/env python
#
# Copyright (C) 2021 Vygruppen
#
# Distributed under terms of the MIT license.

"""
A Lambda function that publishes custom CloudWatch metrics for managed instances
where the AWS API reports that the SSM or ECS agent is disconnected.
"""
import json
import logging
import os
import boto3
from typing import Any, Dict, List

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

ECS = boto3.client("ecs")
SSM = boto3.client("ssm")
CLOUDWATCH = boto3.client("cloudwatch")

DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
METRIC_NAMESPACE = os.environ["METRIC_NAMESPACE"]
METRIC_NAMES = json.loads(os.environ["METRIC_NAMES"])


def get_ecs_container_instances(cluster: str = "", filter_query: str = "", client=None):
    """Return a list of dictionaries describing ECS container instances"""
    if client is None:
        client = boto3.client("ecs")
    kwargs = {
        **({"cluster": cluster} if cluster else {}),
        **({"filter": filter_query} if filter_query else {}),
    }
    paginator = client.get_paginator("list_container_instances")
    iterator = paginator.paginate(**kwargs)
    container_instance_arns = []
    for page in iterator:
        if len(page["containerInstanceArns"]) == 0:
            break
        container_instance_arns += page["containerInstanceArns"]
    LOGGER.info(
        "Found %s container instance ARNs matching filter query '%s'",
        len(container_instance_arns),
        filter_query,
    )
    container_instances = []
    if len(container_instance_arns):
        container_instances = client.describe_container_instances(
            cluster=cluster, containerInstances=container_instance_arns
        )["containerInstances"]
    return container_instances


def get_ssm_managed_instances(filters: List[Dict[str, Any]] = [], client=None):
    """Return a list of dictionaries describing SSM-managed instances"""
    if client is None:
        client = boto3.client("ssm")
    paginator = client.get_paginator("describe_instance_information")
    iterator = paginator.paginate(**{"Filters": filters} if len(filters) else {})
    instance_information_list = []
    for page in iterator:
        if len(page["InstanceInformationList"]) == 0:
            break
        instance_information_list += page["InstanceInformationList"]
    LOGGER.info(
        "Found %s managed instances",
        len(instance_information_list),
    )
    return instance_information_list


def get_ssm_connectivity_metrics(
    ssm_managed_instances: List[Dict[str, Any]] = [],
    metric_name: str = METRIC_NAMES.get(
        "ssm_agent_disconnected", "SSMAgentDisconnected"
    ),
    storage_resolution: int = 1,
) -> List[Dict[str, Any]]:
    """Return a list of CloudWatch metric data objects for disconnected SSM-managed instances"""
    metrics = []
    disconnected_instances = list(
        filter(
            lambda managed_instance: managed_instance["PingStatus"] != "Online",
            ssm_managed_instances,
        )
    )
    for managed_instance in disconnected_instances:
        instance_name = managed_instance["Name"]
        instance_id = managed_instance["InstanceId"]
        if instance_name:
            metrics.append(
                {
                    "MetricName": metric_name,
                    "Unit": "Count",
                    "Value": 1,
                    "Dimensions": [{"Name": "InstanceName", "Value": instance_name}],
                    "StorageResolution": storage_resolution,
                }
            )
        metrics.append(
            {
                "MetricName": metric_name,
                "Unit": "Count",
                "Value": 1,
                "Dimensions": [{"Name": "InstanceId", "Value": instance_id}],
                "StorageResolution": storage_resolution,
            }
        )
    return metrics


def get_ecs_connectivity_metrics(
    ecs_container_instances: List[Dict[str, Any]] = [],
    metric_name: str = METRIC_NAMES.get(
        "ecs_agent_disconnected", "ECSAgentDisconnected"
    ),
    storage_resolution: int = 1,
) -> List[Dict[str, Any]]:
    """Return a list of CloudWatch metric data objects for disconnected ECS container instances"""
    metrics = []
    for managed_instance in ecs_container_instances:
        instance_name = managed_instance["Name"]
        instance_id = managed_instance["ec2InstanceId"]
        if instance_name:
            metrics.append(
                {
                    "MetricName": metric_name,
                    "Unit": "Count",
                    "Value": 1,
                    "Dimensions": [{"Name": "InstanceName", "Value": instance_name}],
                    "StorageResolution": storage_resolution,
                }
            )
        metrics.append(
            {
                "MetricName": metric_name,
                "Unit": "Count",
                "Value": 1,
                "Dimensions": [{"Name": "InstanceId", "Value": instance_id}],
                "StorageResolution": storage_resolution,
            }
        )
    return metrics


def get_augmented_ecs_container_instances(
    ecs_container_instances, ssm_managed_instances
):
    """Return a list of container instances augmented with the name of the SSM-managed instance it belongs to"""
    augmented_container_instances = []
    for container_instance in ecs_container_instances:
        instance_id = container_instance["ec2InstanceId"]
        ssm_managed_instance = next(
            (
                managed_instance
                for managed_instance in ssm_managed_instances
                if managed_instance["InstanceId"] == instance_id
            ),
            {},
        )
        if len(ssm_managed_instance) == 0:
            LOGGER.warning(
                "The instance ID of the container instance was '%s', but no instances with this ID is currently registered in SSM",
                instance_id,
            )
        augmented_container_instances.append(
            {**container_instance, "Name": ssm_managed_instance.get("Name", "")}
        )
    return augmented_container_instances


def publish_cloudwatch_metrics(
    metric_namespace: str,
    metrics: List[Dict[str, Any]],
    client=None,
    dry_run: bool = DRY_RUN,
):
    """Publish a list of CloudWatch metric objects"""
    if client is None:
        client = boto3.client("cloudwatch")
    # Batch the requests due to API limits (max. 20 metrics per API call)
    LOGGER.info("Publishing %s metrics to CloudWatch", len(metrics))
    batch_size = 20
    for i in range(0, len(metrics), batch_size):
        batch_number = (i // batch_size) + 1
        batch = metrics[i : i + batch_size]
        LOGGER.debug("Publishing batch %d to CloudWatch", batch_number)
        if not dry_run:
            client.put_metric_data(
                Namespace=metric_namespace,
                MetricData=batch,
            )


def lambda_handler(event: Dict[str, Any], _: Any):
    LOGGER.info("Lambda received event '%s'", json.dumps(event))
    metric_namespace = METRIC_NAMESPACE
    dry_run = DRY_RUN
    if dry_run:
        LOGGER.info(
            "The current execution is configured as a dry-run, meaning no write operations will be performed against the AWS API"
        )

    ecs_cluster = event.get("ecs_cluster", "")
    ecs_instance_filter_query = event.get(
        "ecs_instance_filter_query", "instance:agentConnected == false"
    )
    ssm_instance_filters = event.get(
        "ssm_instance_filters", [{"Key": "ResourceType", "Values": ["ManagedInstance"]}]
    )
    ssm_managed_instances = get_ssm_managed_instances(
        filters=ssm_instance_filters, client=SSM
    )
    ecs_container_instances = get_ecs_container_instances(
        ecs_cluster, filter_query=ecs_instance_filter_query, client=ECS
    )
    augmented_ecs_container_instances = get_augmented_ecs_container_instances(
        ecs_container_instances, ssm_managed_instances
    )
    ssm_metrics = get_ssm_connectivity_metrics(ssm_managed_instances)
    ecs_metrics = get_ecs_connectivity_metrics(augmented_ecs_container_instances)
    metrics = ssm_metrics + ecs_metrics
    publish_cloudwatch_metrics(
        metric_namespace, metrics, client=CLOUDWATCH, dry_run=dry_run
    )
