#!/bin/bash
set -e

sed -i -e 's/#root:.*/root: support@stsoftware.com.au/g' /etc/aliases
yum update –y
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key

yum install -y awslogs amazon-efs-utils jenkins ntp

mkdir -p /home/jenkins

mount -t efs fs-cb20bcf2:/ /home/jenkins

chown -R jenkins:jenkins /home/jenkins
sed --in-place -E "s( *JENKINS_HOME *=)(.*)/\1/home/jenkins/" /etc/sysconfig/jenkins

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
chkconfig ntpd on

# Set up logs
sed --in-place -E "s/( *region *=)(.*)/\1 ap-southeast-2/" /etc/awslogs/awscli.conf

echo "[general]" > /etc/awslogs/awslogs.conf
echo "state_file = /var/lib/awslogs/agent-state" >> /etc/awslogs/awslogs.conf
echo "use_gzip_http_content_encoding=true" >> /etc/awslogs/awslogs.conf

echo "" >> /etc/awslogs/awslogs.conf
echo "[/var/log/messages]" >> /etc/awslogs/awslogs.conf
echo "log_group_name = tp-php_/var/log/messages" >> /etc/awslogs/awslogs.conf
echo "datetime_format = %b %d %H:%M:%S" >> /etc/awslogs/awslogs.conf
echo "file = /var/log/messages" >> /etc/awslogs/awslogs.conf
echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf

systemctl restart awslogsd.service
service jenkins start
