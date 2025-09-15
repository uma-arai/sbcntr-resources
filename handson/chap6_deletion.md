# 6章のリソース削除手順

リソースの数が多いため、Cloudshellを立ち上げて極力AWS CLIコマンドによって削除をしていきます。
一部、5章のリソースも巻き込みで削除をしています。

```shell
# AWS CLIのデフォルトリージョンを設定
export AWS_REGION=ap-northeast-1
# Pagerを無効化
export AWS_PAGER=""
```

## 前提条件

- 適切なIAM権限をもつユーザーでログインしていること（AdministratorAccess推奨）

## FISの実験テンプレートとIAMリソースの削除

FISの実験テンプレートとIAMリソースを削除します。

### FIS実験テンプレートの削除

```shell
aws fis list-experiment-templates --region ap-northeast-1 | jq -r '.experimentTemplates[] | "\(.id)"' | xargs -I@ aws fis delete-experiment-template --id @ --region $AWS_REGION
```

### FIS関連IAMロールの削除

```shell
# FIS実験用ロールを削除
ROLE_NAME=SbcntrFISRole
aws iam list-attached-role-policies \
--role-name $ROLE_NAME   \
--query 'AttachedPolicies[*].PolicyArn' | jq -r ".[]" | xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME

# SSMエージェント用ロールを削除
ROLE_NAME=SbcntrSSMManagedInstanceRole
aws iam list-attached-role-policies \
--role-name $ROLE_NAME   \
--query 'AttachedPolicies[*].PolicyArn' | jq -r ".[]" | xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME
```

## Step Functions

Step Functionsのステートマシンと関連リソースを削除します。

### ステートマシンの削除

```shell
 aws stepfunctions list-state-machines --region $AWS_REGION --query 'stateMachines[*].stateMachineArn' \
 | jq -r ".[]" \
 | grep -i "sbcntr" \
 | xargs -I@ aws stepfunctions delete-state-machine --state-machine-arn @
 ```

### EventBridgeスケジューラの削除

```shell
aws scheduler delete-schedule \
  --name SbcntrReservationCheckScheduler \
  --region $AWS_REGION
```

### Step Functions用IAMリソースの削除

```shell
# Step Functions用
ROLE_NAME=SbcntrStepFunctionsBatchRole
aws iam list-attached-role-policies \
--role-name $ROLE_NAME   \
--query 'AttachedPolicies[*].PolicyArn' \
| jq -r ".[]" \
| xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME

# EventBridgeスケジューラ用
ROLE_NAME=SbcntrSchedulerRole
aws iam list-attached-role-policies \
--role-name $ROLE_NAME   \
--query 'AttachedPolicies[*].PolicyArn' \
| jq -r ".[]" \
| xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME

# バッチ用
ROLE_NAME=SbcntrEcsBatchTaskRole
aws iam list-attached-role-policies \
--role-name $ROLE_NAME   \
--query 'AttachedPolicies[*].PolicyArn' \
| jq -r ".[]" \
| xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME
```

## AWS X-Ray

X-Ray関連のリソースを削除します。

### Pull through cacheの削除

```shell
# Pull through cacheルールを削除
aws ecr delete-pull-through-cache-rule --ecr-repository-prefix sbcntr-ecr-public --region $AWS_REGION
```

## Amazon GuardDutyの無効化

GuardDutyとランタイムモニタリングを無効化します。

```shell
# GuardDutyディテクターIDを取得
DETECTOR_ID=$(aws guardduty list-detectors --region $AWS_REGION --query 'DetectorIds[0]' --output text)

# ランタイムモニタリングを無効化
aws guardduty update-detector \
  --detector-id $DETECTOR_ID \
  --features Name=RUNTIME_MONITORING,Status=DISABLED \
  --region $AWS_REGION

# GuardDutyを無効化
aws guardduty delete-detector --detector-id $DETECTOR_ID --region $AWS_REGION
```

## FireLens/ログ収集基盤

### S3バケットの削除

```shell
BUCKET_NAME=sbcntr-application-logs-123456789012
# バケット内のオブジェクトを削除（バケット名は実際のものに置き換え）
aws s3 rm s3://$BUCKET_NAME --recursive

# バケットを削除
aws s3api delete-bucket --bucket $BUCKET_NAME --region $AWS_REGION
```

## AWS WAF

### WAF保護パックの削除

```shell

WEB_ACL_INFO=$(aws wafv2 list-web-acls --scope REGIONAL --region $AWS_REGION | jq -r '.WebACLs[] | select(.Name=="sbcntr-frontend-app") | {Id: .Id, LockToken: .LockToken, Arn: .ARN}')
WEB_ACL_ID=$(echo $WEB_ACL_INFO | jq -r .Id)
WEB_ACL_ARN=$(echo $WEB_ACL_INFO | jq -r .Arn)
LOCK_TOKEN=$(echo $WEB_ACL_INFO | jq -r .LockToken)

# 関連付けられているリソースを確認して解除
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn $WEB_ACL_ARN \
  --region $AWS_REGION  \
  | jq -r ".ResourceArns[]" \
  | grep -i "sbcntr" \
  | xargs -I@ aws wafv2 disassociate-web-acl --resource-arn @ --region $AWS_REGION

# WAF WebACLを削除
aws wafv2 delete-web-acl \
  --scope REGIONAL \
  --id $WEB_ACL_ID \
  --name sbcntr-frontend-app \
  --lock-token $LOCK_TOKEN \
  --region $AWS_REGION
```

### CloudWatch Logsロググループの削除

```shell
aws logs delete-log-group --log-group-name aws-waf-logs-sbcntr-frontend-app --region $AWS_REGION
```

## Amazon Inspectorの無効化

Inspectorの拡張スキャンとプッシュ時スキャンを無効化します。

```shell
# Inspectorを無効化
aws inspector2 disable --resource-types ECR EC2 --region $AWS_REGION
```

## CI/CD - Codeシリーズ

### CodePipelineの削除

```shell
aws codepipeline delete-pipeline --name sbcntr-frontend-app --region $AWS_REGION
```

### CodeBuildプロジェクトの削除

```shell
aws codebuild delete-project --name sbcntr-frontend-app --region $AWS_REGION
```

### GitHub Connectionの削除

```shell
# Connection ARNを取得
aws codestar-connections list-connections --query "Connections[?ConnectionName=='SbcntrGitHubConnection'].ConnectionArn" --output text \
| xargs -I@ aws codestar-connections delete-connection --connection-arn @ --region $AWS_REGION
```

## ECRリポジトリの削除

```shell
# FireLens用コンテナリポジトリを削除
aws ecr delete-repository \
  --repository-name sbcntr-base \
  --force --region $AWS_REGION

# Pull through cache用コンテナリポジトリを削除
aws ecr delete-repository \
  --repository-name sbcntr-ecr-public/amazon-ssm-agent/amazon-ssm-agent \
  --force --region $AWS_REGION
aws ecr delete-repository \
  --repository-name sbcntr-ecr-public/aws-observability/aws-otel-collector \
  --force --region $AWS_REGION

# Batch用コンテナリポジトリを削除
aws ecr delete-repository \
  --repository-name sbcntr-batch-app \
  --force --region $AWS_REGION
```

## VPCエンドポイントの削除

CloudFormationによって作成されたVPCエンドポイントに対しては、次のコマンドで削除をしてください。

```shell
aws cloudformation delete-stack --stack-name sbcntr-vpcendpoint
```

手動で作成した方は次のコマンドを順に実行してください。

```shell
# VPCエンドポイントの一覧を確認
aws ec2 describe-vpc-endpoints --region $AWS_REGION

# 各エンドポイントを削除（エンドポイントIDは実際のものに置き換え）
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids <endpoint-id> --region $AWS_REGION
```
