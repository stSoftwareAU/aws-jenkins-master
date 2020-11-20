#!/bin/bash
set -e

sed -i -e 's/#root:.*/root: support@stsoftware.com.au/g' /etc/aliases

# wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat/jenkins.repo
# rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key


yum update –y
amazon-linux-extras enable corretto8

yum install -y java-1.8.0-amazon-corretto awslogs amazon-efs-utils jenkins ntp git jq

mkdir -p /home/jenkins

mount -t efs fs-cb20bcf2:/ /home/jenkins

#chown -R -v jenkins:jenkins /home/jenkins
sed --in-place -E "s/( *JENKINS_HOME *=)(.*)/\1\/home\/jenkins/" /etc/sysconfig/jenkins

usermod -s /bin/bash -d /home/jenkins jenkins

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
chkconfig ntpd on

# Set up logs
sed --in-place -E "s/( *region *=)(.*)/\1 ap-southeast-2/" /etc/awslogs/awscli.conf

echo "[general]" > /etc/awslogs/awslogs.conf
echo "state_file = /var/lib/awslogs/agent-state" >> /etc/awslogs/awslogs.conf
echo "use_gzip_http_content_encoding=true" >> /etc/awslogs/awslogs.conf

echo "" >> /etc/awslogs/awslogs.conf
echo "[/var/log/cloud-init-output.log]" >> /etc/awslogs/awslogs.conf
echo "log_group_name = jenkins_master/var/log/cloud-init-output.log" >> /etc/awslogs/awslogs.conf
echo "datetime_format = %b %d %H:%M:%S" >> /etc/awslogs/awslogs.conf
echo "file = /var/log/cloud-init-output.log" >> /etc/awslogs/awslogs.conf
echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf

ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 associate-address --instance-id $ID --allocation-id eipalloc-0c52226d880174da9 --region ap-southeast-2

systemctl restart awslogsd.service
service jenkins start
