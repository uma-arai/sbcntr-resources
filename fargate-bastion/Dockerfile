FROM amazonlinux:2
RUN yum install -y sudo jq awscli shadow-utils htop lsof telnet bind-utils yum-utils && \
    yum install -y https://s3.ap-northeast-1.amazonaws.com/amazon-ssm-ap-northeast-1/latest/linux_amd64/amazon-ssm-agent.rpm && \
    yum install -y yum localinstall https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm && \
    yum-config-manager --disable mysql80-community && \
    yum-config-manager --enable mysql57-community && \
    yum install -y mysql-community-client && \
    adduser ssm-user && echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users && \
    mv /etc/amazon/ssm/amazon-ssm-agent.json.template /etc/amazon/ssm/amazon-ssm-agent.json && \
    mv /etc/amazon/ssm/seelog.xml.template /etc/amazon/ssm/seelog.xml
COPY run.sh /run.sh
CMD ["sh", "/run.sh"]
