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
TMP_PATH=$(echo $PATH | sed -e 's#/usr/local/bin:##g') && PATH=/usr/local/bin:$TMP_PATH

# Docker ECSインテグレーションのダウンロード
curl -Lo docker-ecs.sh https://raw.githubusercontent.com/docker/compose-cli/main/scripts/install/install_linux.sh

# 44054930=v1.0.17(https://api.github.com/repos/docker/compose-cli/releases)
sed -i -e 's/latest/44054930/g' docker-ecs.sh

# Docker ECSインテグレーションのインストール
# インストールに失敗するときは前述のsedコマンドをスキップしてお試しください
sh docker-ecs.sh

# これ以降で必要なツールのインストール
sudo yum install -y jq

echo "Setup complete!"
