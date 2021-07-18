#!/bin/sh

APP_DIR=~/environment/sbcntr-backend
METADATA_URL=http://169.254.169.254/latest/meta-data/iam/security-credentials

ls ${APP_DIR}
if [ $? -ne 0 ]; then
    echo "Error: 事前にsbcntr-backendをダウンロードしてください"
    exit 1
fi

ROLE_STATUS=$(curl -LI -s ${METADATA_URL} -o /dev/null -w '%{http_code}')
if [ $ROLE_STATUS -ne 200 ]; then
    echo "Error: IAMロールが設定されていません。EC2ダッシュボードからIAMロールを設定してください。"
    exit 1
fi


cd ${APP_DIR}
# インストール時にPATHの記述順序でエラーが出る対策
TmpPATH=$(echo $PATH | sed -e 's#/usr/local/bin:##g') && PATH=/usr/local/bin:$TmpPATH

# Docker ECSインテグレーションのダウンロード
curl -Lo docker-ecs.sh https://raw.githubusercontent.com/docker/compose-cli/main/scripts/install/install_linux.sh

# 44054930=v1.0.17(https://api.github.com/repos/docker/compose-cli/releases)
sed -i -e 's/latest/44054930/g' docker-ecs.sh

# Docker ECSインテグレーションのインストール
# インストールに失敗するときは前述のsedコマンドをスキップしてお試しください
sh docker-ecs.sh

# IAMロールのプロファイルを取得できないため手動で設定
sudo yum install -y jq
ROLE_NAME=$(curl -s ${METADATA_URL})
export AWS_SESSION_TOKEN=$(curl -s ${METADATA_URL}/${ROLE_NAME} | jq -r .Token)
export AWS_SECRET_ACCESS_KEY=$(curl -s ${METADATA_URL}/${ROLE_NAME} | jq -r .SecretAccessKey)
export AWS_ACCESS_KEY_ID=$(curl -s ${METADATA_URL}/${ROLE_NAME} | jq -r .AccessKeyId)
export AWS_DEFAULT_REGION=ap-northeast-1

# ECRの認証情報の取得
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
aws ecr --region ap-northeast-1 get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/sbcntr-backend

echo "Setup complete!"
