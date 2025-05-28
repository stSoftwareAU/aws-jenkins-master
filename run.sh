#!/bin/bash
set -ex

yum update –y
yum install -y awslogs

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


function retry {
  local max_attempts=${ATTEMPTS-6} ##ATTEMPTS (default 6)
  local timeout=${TIMEOUT-1}       ##TIMEOUT in seconds (default 1.) doubles on each attempt
  local attempt=0
  local exitCode=0

  set +e
  while [[ $attempt < $max_attempts ]]
  do
    "$@" && { 
      exitCode=0
      break 
    }
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done
  set -e

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}


sed -i -e 's/#root:.*/root: support@stsoftware.com.au/g' /etc/aliases

# wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat/jenkins.repo
# rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
retry wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
retry rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
retry rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key
retry rpm --import https://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key


amazon-linux-extras enable corretto8
amazon-linux-extras install -y epel
yum install -y java-1.8.0-amazon-corretto amazon-efs-utils ntp git jq

#yum install -y jenkins-2.319.3-1.1

# alternative way to download jenkins and install it as the Jenkins main archive site got problem
wget https://archives.jenkins-ci.org/redhat-stable/jenkins-2.319.3-1.1.noarch.rpm
yum localinstall jenkins-2.319.3-1.1.noarch.rpm

JENKINS_USER_ID=996
usermod -u ${JENKINS_USER_ID} jenkins
mkdir -p /home/jenkins
usermod --home /home/jenkins jenkins
mount -t efs fs-cb20bcf2:/ /home/jenkins
#chown -R -v jenkins:jenkins /home/jenkins
sed --in-place -E "s/( *JENKINS_HOME *=)(.*)/\1\/home\/jenkins/" /etc/sysconfig/jenkins

usermod -s /bin/bash -d /home/jenkins jenkins

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
chkconfig ntpd on

service jenkins start
