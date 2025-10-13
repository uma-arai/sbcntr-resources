# 5章のリソース削除手順

5章で作成したAWSリソースを削除する手順です。依存関係を考慮した順序で削除を進めてください。
リソースの数が多いため、Cloudshellを立ち上げてAWS CLIコマンドによって削除をしていきます。

```shell
# AWS CLIのデフォルトリージョンを設定
export AWS_REGION=ap-northeast-1
# Pagerを無効化
export AWS_PAGER=""
```

## 前提条件

- 適切なIAM権限をもつユーザーでログインしていること（AdministratorAccess推奨）

## 削除手順

### 1. ECSサービスの削除

ECSサービスを削除し、起動中のタスクを停止します。

```shell
# フロントエンドサービスを削除
aws ecs update-service \
  --cluster sbcntr-app \
  --service sbcntr-frontend-app \
  --desired-count 0 \
  --force-new-deployment

aws ecs delete-service \
  --cluster sbcntr-app \
  --service sbcntr-frontend-app \
  --force

# バックエンドサービスのCloudFormationスタックを削除
aws cloudformation delete-stack --stack-name sbcntr-backend-app
```

### 2. ECSクラスターの削除

すべてのサービスが削除されてから実行してください。

```shell
aws ecs delete-cluster --cluster sbcntr-app
```

### 3. Application Load Balancerとターゲットグループの削除

```shell
# ALBを削除
aws elbv2 describe-load-balancers \
  --names sbcntr-ingress \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text | xargs -I@ aws elbv2 delete-load-balancer --load-balancer-arn @
```

少し時間を置いてからターゲットグループを削除してください。

```shell
# ターゲットグループを削除
aws elbv2 delete-target-group \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names sbcntr-frontapp-blue \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 delete-target-group \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names sbcntr-frontapp-green \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

### 4. RDS（Aurora）の削除

```shell
# DBクラスター内のインスタンスを削除
aws rds delete-db-instance \
  --db-instance-identifier sbcntr-main-instance-1 \
  --skip-final-snapshot \
  --delete-automated-backups

# インスタンス削除が完了するまで待機（約5-10分）
aws rds wait db-instance-deleted --db-instance-identifier sbcntr-main-instance-1 && \
aws rds delete-db-cluster \
  --db-cluster-identifier sbcntr-main \
  --skip-final-snapshot

# サブネットグループを削除
aws rds delete-db-subnet-group --db-subnet-group-name sbcntr-main
```

### 5. ECRリポジトリの削除

```shell
# バックエンドアプリのリポジトリを削除
aws ecr delete-repository \
  --repository-name sbcntr-backend-app \
  --force

# フロントエンドアプリのリポジトリを削除
aws ecr delete-repository \
  --repository-name sbcntr-frontend-app \
  --force
```

### 6. Secrets Managerのシークレット削除

```shell
# シークレットを削除（即座に削除する）
aws secretsmanager delete-secret \
  --secret-id $(aws secretsmanager list-secrets \
    --query 'SecretList[?contains(Name, `sbcntr`)].ARN' \
    --output text) \
  --force-delete-without-recovery
```

### 7. CloudWatch Logsの削除

```shell
# ロググループを削除
aws logs list-log-groups --query 'logGroups[*].logGroupName' | jq -r ".[]" | grep -i "sbcntr" | xargs -I@ aws logs delete-log-group --log-group-name @
```

### VPCエンドポイント

6章で削除済みの場合は実施不要です。
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

### 10. 開発用EC2の削除（CloudFormation）

```shell
aws cloudformation delete-stack --stack-name sbcntr-pseudo-cloud9
```

### 11. ネットワークリソースの削除（CloudFormation）

最後に基盤となるネットワークリソースを削除します。

```shell
aws cloudformation delete-stack --stack-name sbcntr-base
```

### IAMリソースの削除

残ったIAMポリシーとIAMロールを消していきましょう。

```shell
# IAMロールの一覧を確認
aws iam list-roles --query 'Roles[*].RoleName' | jq -r ".[]" | egrep -i "sbcntr|ecsTaskExecutionRole|EcsInfrastructureRoleForLoadBalancers"
```

表示されたロールから順番にポリシーをデタッチして削除をしましょう。

```shell
# タスクロール
ROLL_NAME=SbcntrECSTaskRole
aws iam list-attached-role-policies \
--role-name $ROLL_NAME  \
--query 'AttachedPolicies[*].PolicyArn' | jq -r ".[]" | xargs -I@ aws iam detach-role-policy --role-name $ROLL_NAME --policy-arn @
aws iam delete-role-policy --role-name $ROLL_NAME --policy-name SbcntrEcsTask
aws iam delete-role --role-name $ROLL_NAME

# タスク実行ロール
ROLE_NAME=ecsTaskExecutionRole
aws iam list-attached-role-policies \
  --role-name $ROLE_NAME  \
  --query 'AttachedPolicies[*].PolicyArn' | jq -r ".[]" | xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME

# Blue/Greenデプロイ用ロール
ROLE_NAME=EcsInfrastructureRoleForLoadBalancers
aws iam list-attached-role-policies \
  --role-name $ROLE_NAME  \
  --query 'AttachedPolicies[*].PolicyArn' | jq -r ".[]" | xargs -I@ aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn @
aws iam delete-role --role-name $ROLE_NAME
```

最後にIAMポリシーを削除します。

```shell
# IAMポリシーの一覧を確認
aws iam list-policies --query 'Policies[*].PolicyName' | jq -r ".[]" | grep -i "sbcntr"
# 一括削除
aws iam list-policies --query 'Policies[*].PolicyName' | jq -r ".[]" | grep -i "sbcntr" | xargs -I@ aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/@
```

ポリシーバージョンを更新しているものがある場合は、次のエラーとなります。

```
An error occurred (DeleteConflict) when calling the DeletePolicy operation: This policy has more than one version. Before you delete a policy, you must delete the policy's versions. The default version is deleted with the policy.
```

これらについてはAWSマネジメントコンソールのIAM画面から手動で削除をしてください。

## 削除の確認

すべてのリソースが削除されたことを確認します。

```shell
# CloudFormationスタックの確認
aws cloudformation list-stacks \
  --stack-status-filter DELETE_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `sbcntr`)].StackName'

# VPCの確認
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=sbcntr-*" \
  --query 'Vpcs[].VpcId'
```

## 注意事項

- RDSの削除には時間がかかります（5-10分程度）
- CloudFormationスタックの削除が失敗した場合は、エラーメッセージを確認して手動でリソースを削除する必要があります
- VPCエンドポイントは課金対象のため、確実に削除されたことを確認してください
- Secrets Managerのシークレットは通常7日間の待機期間がありますが、`--force-delete-without-recovery`オプションで即座に削除できます

## トラブルシューティング

### CloudFormationスタックが削除できない場合

依存関係のあるリソースが残っている可能性があります。CloudFormationのイベントタブでエラーを確認し、該当リソースを手動で削除してください。

### VPCが削除できない場合

VPC内にまだリソースが残っている可能性があります。特にENI（Elastic Network Interface）が残っていないか確認してください。

```shell
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,Description]'
```
