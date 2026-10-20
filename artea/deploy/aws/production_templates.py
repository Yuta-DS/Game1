"""Generate reviewable CloudFormation JSON; this module never contacts AWS."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
def ref(name): return {"Ref": name}
def get(name, attr): return {"Fn::GetAtt": [name, attr]}
def sub(text): return {"Fn::Sub": text}
def resource(kind, **properties): return {"Type": "AWS::" + kind, "Properties": properties}
def retain(item): return dict(item, DeletionPolicy="Retain", UpdateReplacePolicy="Retain")
def snapshot(item): return dict(item, DeletionPolicy="Snapshot", UpdateReplacePolicy="Snapshot")
def trust(service): return {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": service}, "Action": "sts:AssumeRole"}]}
def policy(actions, resources): return {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": actions, "Resource": resources}]}


def backend():
    r = {}
    r["Vpc"] = resource("EC2::VPC", CidrBlock="10.40.0.0/16", EnableDnsSupport=True, EnableDnsHostnames=True)
    r["Gateway"] = resource("EC2::InternetGateway")
    r["GatewayAttachment"] = resource("EC2::VPCGatewayAttachment", VpcId=ref("Vpc"), InternetGatewayId=ref("Gateway"))
    for index, az in enumerate(["A", "B"]):
        for category, offset in [("Public", 0), ("Private", 10)]:
            r[category + az] = resource("EC2::Subnet", VpcId=ref("Vpc"), CidrBlock=f"10.40.{index + offset}.0/24",
                AvailabilityZone={"Fn::Select": [index, {"Fn::GetAZs": ""}]}, MapPublicIpOnLaunch=False)
            table = category + "Routes" + az
            r[table] = resource("EC2::RouteTable", VpcId=ref("Vpc"))
            r[category + "Association" + az] = resource("EC2::SubnetRouteTableAssociation", SubnetId=ref(category + az), RouteTableId=ref(table))
        r["Address" + az] = dict(resource("EC2::EIP", Domain="vpc"), DependsOn="GatewayAttachment")
        r["Nat" + az] = resource("EC2::NatGateway", AllocationId=get("Address" + az, "AllocationId"), SubnetId=ref("Public" + az))
        r["PublicDefault" + az] = dict(resource("EC2::Route", RouteTableId=ref("PublicRoutes" + az), DestinationCidrBlock="0.0.0.0/0", GatewayId=ref("Gateway")), DependsOn="GatewayAttachment")
        r["PrivateDefault" + az] = resource("EC2::Route", RouteTableId=ref("PrivateRoutes" + az), DestinationCidrBlock="0.0.0.0/0", NatGatewayId=ref("Nat" + az))
    r["S3Endpoint"] = resource("EC2::VPCEndpoint", VpcId=ref("Vpc"), VpcEndpointType="Gateway", ServiceName=sub("com.amazonaws.${AWS::Region}.s3"), RouteTableIds=[ref("PrivateRoutesA"), ref("PrivateRoutesB")])
    for name in ["App", "Database", "LoadBalancer"]:
        r[name + "Security"] = resource("EC2::SecurityGroup", GroupDescription="Artea " + name, VpcId=ref("Vpc"))
    for name, target, source, port in [("DbIngress", "Database", "App", 5432), ("AppIngress", "App", "LoadBalancer", 8000)]:
        r[name] = resource("EC2::SecurityGroupIngress", GroupId=ref(target + "Security"), SourceSecurityGroupId=ref(source + "Security"), IpProtocol="tcp", FromPort=port, ToPort=port)
    r["ArtworkBucket"] = retain(resource("S3::Bucket", VersioningConfiguration={"Status": "Enabled"},
        PublicAccessBlockConfiguration={"BlockPublicAcls": True, "IgnorePublicAcls": True, "BlockPublicPolicy": True, "RestrictPublicBuckets": True},
        OwnershipControls={"Rules": [{"ObjectOwnership": "BucketOwnerEnforced"}]},
        BucketEncryption={"ServerSideEncryptionConfiguration": [{"ServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]},
        LifecycleConfiguration={"Rules": [{"Id": "CleanupOldVersions", "Status": "Enabled", "NoncurrentVersionExpiration": {"NoncurrentDays": 90}, "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 1}}]}))
    r["ArtworkBucketPolicy"] = resource("S3::BucketPolicy", Bucket=ref("ArtworkBucket"), PolicyDocument={"Version": "2012-10-17", "Statement": [{"Effect": "Deny", "Principal": "*", "Action": "s3:*", "Resource": [get("ArtworkBucket", "Arn"), sub("${ArtworkBucket.Arn}/*")], "Condition": {"Bool": {"aws:SecureTransport": "false"}}}]})
    for name, template in [("OriginSecret", {}), ("ApplicationDbSecret", {"username": "artea_app"})]:
        r[name] = retain(resource("SecretsManager::Secret", GenerateSecretString={"SecretStringTemplate": json.dumps(template), "GenerateStringKey": "password" if template else "token", "PasswordLength": 48, "ExcludePunctuation": True}))
    r["DatabaseSubnets"] = resource("RDS::DBSubnetGroup", DBSubnetGroupDescription="Private two-AZ database", SubnetIds=[ref("PrivateA"), ref("PrivateB")])
    r["Database"] = snapshot(resource("RDS::DBInstance", Engine="postgres", DBInstanceClass=ref("DbInstanceClass"),
        DBName="artea", MasterUsername="artea_owner", ManageMasterUserPassword=True,
        AllocatedStorage="30", MaxAllocatedStorage=200, StorageType="gp3", StorageEncrypted=True,
        MultiAZ=True, PubliclyAccessible=False, BackupRetentionPeriod=14, DeletionProtection=True,
        CopyTagsToSnapshot=True, AutoMinorVersionUpgrade=True, EnableCloudwatchLogsExports=["postgresql", "upgrade"],
        VPCSecurityGroups=[ref("DatabaseSecurity")], DBSubnetGroupName=ref("DatabaseSubnets")))
    r["UserPool"] = retain(resource("Cognito::UserPool", UserPoolName=sub("${AWS::StackName}-players"),
        DeletionProtection="ACTIVE", AutoVerifiedAttributes=["email"], UsernameConfiguration={"CaseSensitive": False},
        AccountRecoverySetting={"RecoveryMechanisms": [{"Name": "verified_email", "Priority": 1}]},
        Policies={"PasswordPolicy": {"MinimumLength": 14, "RequireLowercase": True, "RequireUppercase": True, "RequireNumbers": True, "RequireSymbols": True, "TemporaryPasswordValidityDays": 1}},
        Schema=[{"Name": "email", "AttributeDataType": "String", "Required": True, "Mutable": True}],
        EmailConfiguration={"EmailSendingAccount": "DEVELOPER", "SourceArn": ref("SesIdentityArn"), "From": ref("AccountEmailFrom")},
        VerificationMessageTemplate={"DefaultEmailOption": "CONFIRM_WITH_CODE"}))
    r["UserClient"] = resource("Cognito::UserPoolClient", UserPoolId=ref("UserPool"), GenerateSecret=True,
        ExplicitAuthFlows=["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"], PreventUserExistenceErrors="ENABLED",
        EnableTokenRevocation=True, AccessTokenValidity=1, IdTokenValidity=1, RefreshTokenValidity=7,
        TokenValidityUnits={"AccessToken": "hours", "IdToken": "hours", "RefreshToken": "days"},
        ReadAttributes=["email", "email_verified"], WriteAttributes=["email"])
    r["Logs"] = resource("Logs::LogGroup", RetentionInDays=30)

    execution_secrets = [ref("OriginSecret"), ref("ApplicationDbSecret")]
    for name, secrets in [("ExecutionRole", execution_secrets), ("MigrationExecutionRole", [ref("ApplicationDbSecret"), get("Database", "MasterUserSecret.SecretArn")])]:
        r[name] = resource("IAM::Role", AssumeRolePolicyDocument=trust("ecs-tasks.amazonaws.com"),
            ManagedPolicyArns=[sub("arn:${AWS::Partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy")],
            Policies=[{"PolicyName": "ReadTaskSecrets", "PolicyDocument": policy(["secretsmanager:GetSecretValue"], secrets)}])
    r["ExecutionRole"]["Properties"]["Policies"][0]["PolicyDocument"]["Statement"][0]["Resource"].append({"Fn::If": ["HasAiSecret", ref("AiSecretArn"), ref("AWS::NoValue")]})
    r["TaskRole"] = resource("IAM::Role", AssumeRolePolicyDocument=trust("ecs-tasks.amazonaws.com"), Policies=[
        {"PolicyName": "CognitoServerClient", "PolicyDocument": policy(["cognito-idp:DescribeUserPoolClient"], [get("UserPool", "Arn")])},
        {"PolicyName": "PrivatePlayerArtwork", "PolicyDocument": policy(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], [sub("${ArtworkBucket.Arn}/users/*")])}])
    r["MigrationRole"] = resource("IAM::Role", AssumeRolePolicyDocument=trust("ecs-tasks.amazonaws.com"))
    r["Cluster"] = resource("ECS::Cluster", ClusterSettings=[{"Name": "containerInsights", "Value": "enabled"}])
    common_env = {"AWS_REGION": ref("AWS::Region"), "DB_HOST": get("Database", "Endpoint.Address"), "DB_NAME": "artea", "DB_SSL_CA": "/app/rds-ca.pem", "AUTO_CREATE_SCHEMA": "false", "AI_ALLOW_LOOPBACK_GUESTS": "0", "MAX_UPLOAD_BYTES": "8000000", "AI_UPSTREAM_TIMEOUT_SECONDS": "35", "CORS_ALLOWED_ORIGINS": "https://invalid.invalid"}
    def environment(values): return [{"Name": key, "Value": value} for key, value in values.items()]
    log = {"LogDriver": "awslogs", "Options": {"awslogs-group": ref("Logs"), "awslogs-region": ref("AWS::Region"), "awslogs-stream-prefix": "api"}}
    app_container = {"Name": "api", "Image": ref("ImageUri"), "Essential": True, "PortMappings": [{"ContainerPort": 8000}],
        "Environment": environment(dict(common_env, DB_USERNAME="artea_app", COGNITO_POOL_ID=ref("UserPool"), COGNITO_CLIENT_ID=ref("UserClient"), ARTWORK_BUCKET=ref("ArtworkBucket"), JWT_SECRET_KEY="unused-production-cognito-RS256-only")),
        "Secrets": [{"Name": "DB_PASSWORD", "ValueFrom": sub("${ApplicationDbSecret}:password::")}, {"Name": "ORIGIN_SECRET", "ValueFrom": sub("${OriginSecret}:token::")}],
        "LogConfiguration": log, "LinuxParameters": {"Capabilities": {"Drop": ["ALL"]}}}
    for key in ["OMNIROUTE_BASE_URL", "OMNIROUTE_CREATIVE_GUIDE_API_KEY", "OMNIROUTE_WORLD_BUILDER_API_KEY", "OMNIROUTE_BACKUP_API_KEY", "OPENROUTER_API_KEY"]:
        app_container["Secrets"].append({"Fn::If": ["HasAiSecret", {"Name": key, "ValueFrom": sub("${AiSecretArn}:" + key + "::")}, ref("AWS::NoValue")]})
    migration_container = {"Name": "migration", "Image": {"Fn::If": ["HasMigrationImage", ref("MigrationImageUri"), ref("ImageUri")]}, "Essential": True, "Command": ["python", "manage_aws.py"],
        "Environment": environment(dict(common_env, DB_USERNAME="artea_owner")),
        "Secrets": [{"Name": "DB_PASSWORD", "ValueFrom": {"Fn::Join": ["", [get("Database", "MasterUserSecret.SecretArn"), ":password::"]]}}, {"Name": "APP_DB_PASSWORD", "ValueFrom": sub("${ApplicationDbSecret}:password::")}], "LogConfiguration": log}
    for name, container, execution, role in [("ApiTask", app_container, "ExecutionRole", "TaskRole"), ("MigrationTask", migration_container, "MigrationExecutionRole", "MigrationRole")]:
        r[name] = resource("ECS::TaskDefinition", Cpu="512", Memory="1024", NetworkMode="awsvpc", RequiresCompatibilities=["FARGATE"], RuntimePlatform={"CpuArchitecture": "X86_64", "OperatingSystemFamily": "LINUX"}, ExecutionRoleArn=get(execution, "Arn"), TaskRoleArn=get(role, "Arn"), ContainerDefinitions=[container])
    r["LoadBalancer"] = resource("ElasticLoadBalancingV2::LoadBalancer", Scheme="internal", Type="application", Subnets=[ref("PrivateA"), ref("PrivateB")], SecurityGroups=[ref("LoadBalancerSecurity")], LoadBalancerAttributes=[{"Key": "routing.http.drop_invalid_header_fields.enabled", "Value": "true"}, {"Key": "idle_timeout.timeout_seconds", "Value": "110"}])
    r["Targets"] = resource("ElasticLoadBalancingV2::TargetGroup", VpcId=ref("Vpc"), Port=8000, Protocol="HTTP", TargetType="ip", HealthCheckPath="/healthz", Matcher={"HttpCode": "200"}, TargetGroupAttributes=[{"Key": "deregistration_delay.timeout_seconds", "Value": "30"}])
    r["Listener"] = resource("ElasticLoadBalancingV2::Listener", LoadBalancerArn=ref("LoadBalancer"), Port=80, Protocol="HTTP", DefaultActions=[{"Type": "forward", "TargetGroupArn": ref("Targets")}])
    r["Service"] = dict(resource("ECS::Service", Cluster=ref("Cluster"), LaunchType="FARGATE", TaskDefinition=ref("ApiTask"), DesiredCount=ref("DesiredCount"),
        AvailabilityZoneRebalancing="ENABLED", HealthCheckGracePeriodSeconds=60,
        DeploymentConfiguration={"MinimumHealthyPercent": 100, "MaximumPercent": 200, "DeploymentCircuitBreaker": {"Enable": True, "Rollback": True}},
        NetworkConfiguration={"AwsvpcConfiguration": {"AssignPublicIp": "DISABLED", "Subnets": [ref("PrivateA"), ref("PrivateB")], "SecurityGroups": [ref("AppSecurity")]}},
        LoadBalancers=[{"ContainerName": "api", "ContainerPort": 8000, "TargetGroupArn": ref("Targets")}]), DependsOn=["Listener", "PrivateDefaultA", "PrivateDefaultB"])
    r["Scaling"] = resource("ApplicationAutoScaling::ScalableTarget", MinCapacity=ref("DesiredCount"), MaxCapacity=6,
        ResourceId=sub("service/${Cluster}/${Service.Name}"), ScalableDimension="ecs:service:DesiredCount", ServiceNamespace="ecs")
    r["CpuScaling"] = resource("ApplicationAutoScaling::ScalingPolicy", PolicyName="api-cpu", PolicyType="TargetTrackingScaling", ScalingTargetId=ref("Scaling"), TargetTrackingScalingPolicyConfiguration={"TargetValue": 60, "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"}, "ScaleInCooldown": 120, "ScaleOutCooldown": 30})
    r["AlbIngress"] = resource("EC2::SecurityGroupIngress", GroupId=ref("LoadBalancerSecurity"), SourcePrefixListId=ref("CloudFrontPrefixListId"), IpProtocol="tcp", FromPort=80, ToPort=80)
    r["VpcOrigin"] = dict(resource("CloudFront::VpcOrigin", VpcOriginEndpointConfig={"Name": sub("${AWS::StackName}-private-api"), "Arn": ref("LoadBalancer"), "HTTPPort": 80, "HTTPSPort": 443, "OriginProtocolPolicy": "http-only"}), DependsOn=["Listener", "AlbIngress", "GatewayAttachment"])
    r["AlarmTopic"] = resource("SNS::Topic", Subscription=[{"Endpoint": ref("OperationsEmail"), "Protocol": "email"}])
    for name, namespace, metric, dimensions, threshold, statistic in [
        ("DatabaseStorage", "AWS/RDS", "FreeStorageSpace", [{"Name": "DBInstanceIdentifier", "Value": ref("Database")}], 5_000_000_000, "Minimum"),
        ("ApiErrors", "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", [{"Name": "LoadBalancer", "Value": get("LoadBalancer", "LoadBalancerFullName")}], 10, "Sum")]:
        r[name + "Alarm"] = resource("CloudWatch::Alarm", Namespace=namespace, MetricName=metric, Dimensions=dimensions, Statistic=statistic, Period=300, EvaluationPeriods=2, Threshold=threshold, ComparisonOperator="LessThanThreshold" if name == "DatabaseStorage" else "GreaterThanThreshold", AlarmActions=[ref("AlarmTopic")], TreatMissingData="notBreaching")
    return {"AWSTemplateFormatVersion": "2010-09-09", "Description": "Artea production backend: Cognito, two private Fargate tasks, Multi-AZ PostgreSQL, private artwork S3.",
        "Conditions": {"HasMigrationImage": {"Fn::Not": [{"Fn::Equals": [ref("MigrationImageUri"), ""]}]}, "HasAiSecret": {"Fn::Not": [{"Fn::Equals": [ref("AiSecretArn"), ""]}]}},
        "Parameters": {
            "MigrationImageUri": {"Type": "String", "Default": "", "Description": "New image for schema preparation before runtime promotion"},
            "AiSecretArn": {"Type": "String", "Default": ""},
            "CloudFrontPrefixListId": {"Type": "String", "AllowedPattern": "pl-[a-f0-9]+"},
            "ImageUri": {"Type": "String", "AllowedPattern": r"[0-9]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9_./-]+@sha256:[a-f0-9]{64}"},
            "DesiredCount": {"Type": "Number", "Default": 0, "AllowedValues": [0, 2]},
            "DbInstanceClass": {"Type": "String", "Default": "db.t4g.medium", "AllowedValues": ["db.t4g.medium", "db.t4g.large", "db.m7g.large"]},
            "SesIdentityArn": {"Type": "String", "AllowedPattern": "arn:aws:ses:[a-z0-9-]+:[0-9]+:identity/.+"},
            "AccountEmailFrom": {"Type": "String", "Description": "Verified SES From email address"},
            "OperationsEmail": {"Type": "String", "Description": "Confirm the SNS email subscription after deployment"}},
        "Resources": r, "Outputs": {
            "ApiDomain": {"Value": get("LoadBalancer", "DNSName")},
            "VpcOriginId": {"Value": ref("VpcOrigin")},
            "OriginSecretArn": {"Value": ref("OriginSecret")}, "UserPoolId": {"Value": ref("UserPool")},
            "ClusterName": {"Value": ref("Cluster")}, "ServiceName": {"Value": get("Service", "Name")},
            "MigrationTaskArn": {"Value": ref("MigrationTask")},
            "PrivateSubnets": {"Value": {"Fn::Join": [",", [ref("PrivateA"), ref("PrivateB")]]}},
            "AppSecurityGroup": {"Value": ref("AppSecurity")}, "ArtworkBucketName": {"Value": ref("ArtworkBucket")}}}


def waf():
    rules = []
    for index, name in enumerate(["AWSManagedRulesCommonRuleSet", "AWSManagedRulesKnownBadInputsRuleSet", "AWSManagedRulesAmazonIpReputationList"]):
        managed = {"VendorName": "AWS", "Name": name}
        # Artwork and AI JSON can exceed the default body inspection length;
        # Flask/API Gateway enforce size. Keep every other managed protection.
        if index == 0: managed["RuleActionOverrides"] = [{"Name": "SizeRestrictions_BODY", "ActionToUse": {"Count": {}}}]
        rules.append({"Name": name, "Priority": index, "OverrideAction": {"None": {}}, "Statement": {"ManagedRuleGroupStatement": managed}, "VisibilityConfig": {"CloudWatchMetricsEnabled": True, "SampledRequestsEnabled": False, "MetricName": name}})
    rules.append({"Name": "AccountRate", "Priority": 3, "Action": {"Block": {}}, "Statement": {"RateBasedStatement": {"Limit": 100, "EvaluationWindowSec": 300, "AggregateKeyType": "IP", "ScopeDownStatement": {"RegexMatchStatement": {"RegexString": "^/api/(login|register|refresh|forgot_password|reset_password|resend_confirmation|confirm_registration)$", "FieldToMatch": {"UriPath": {}}, "TextTransformations": [{"Priority": 0, "Type": "URL_DECODE"}, {"Priority": 1, "Type": "NORMALIZE_PATH"}]}}}}, "VisibilityConfig": {"CloudWatchMetricsEnabled": True, "SampledRequestsEnabled": False, "MetricName": "AccountRate"}})
    return {"AWSTemplateFormatVersion": "2010-09-09", "Description": "Deploy in us-east-1 for CloudFront. WAF managed protections and account throttling.", "Resources": {
        "WebAcl": resource("WAFv2::WebACL", Scope="CLOUDFRONT", DefaultAction={"Allow": {}}, VisibilityConfig={"CloudWatchMetricsEnabled": True, "SampledRequestsEnabled": False, "MetricName": "ArteaEdge"}, Rules=rules)}, "Outputs": {"WebAclArn": {"Value": get("WebAcl", "Arn")}}}


def registry():
    return {"AWSTemplateFormatVersion": "2010-09-09", "Resources": {"Repository": retain(resource("ECR::Repository", ImageTagMutability="IMMUTABLE", ImageScanningConfiguration={"ScanOnPush": True}, LifecyclePolicy={"LifecyclePolicyText": json.dumps({"rules": [{"rulePriority": 1, "description": "Remove old untagged images", "selection": {"tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 30}, "action": {"type": "expire"}}]})}))}, "Outputs": {"RepositoryUri": {"Value": get("Repository", "RepositoryUri")}}}


if __name__ == "__main__":
    for name, template in [("backend-cloudformation.json", backend()), ("waf-cloudformation.json", waf()), ("registry-cloudformation.json", registry())]:
        (HERE / name).write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")
        print(name)
