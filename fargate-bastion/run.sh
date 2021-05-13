#/bin/sh

# Preparation
SSM_SERVICE_ROLE_NAME="SSMServiceRole"
SSM_ACTIVATION_FILE="code.json"
AWS_REGION="ap-northeast-1"

# Create Activation Code on Systems Manager
aws ssm create-activation \
--description "Activation Code for Fargate Bastion" \
--default-instance-name bastion \
--iam-role ${SSM_SERVICE_ROLE_NAME} \
--registration-limit 1 > ${SSM_ACTIVATION_FILE} \
--tags Key=Type,Value=Bastion
--region ${AWS_REGION}

SSM_ACTIVATION_ID=`cat ${SSM_ACTIVATION_FILE} | jq -r .ActivationId`
SSM_ACTIVATION_CODE=`cat ${SSM_ACTIVATION_FILE} | jq -r .ActivationCode`
rm -f ${SSM_ACTIVATION_FILE}

# Activate SSM Agent on Fargate Task
amazon-ssm-agent -register -code "${SSM_ACTIVATION_CODE}" -id "${SSM_ACTIVATION_ID}" -region ${AWS_REGION}

# Delete Activation Code
aws ssm delete-activation --activation-id ${SSM_ACTIVATION_ID}

# Execute SSM Agent
amazon-ssm-agent
