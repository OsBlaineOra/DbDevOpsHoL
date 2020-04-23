#!/bin/bash
#
# DevOps HoL cloud-init script for OCI
#
# Copyright (c) 1982-2020 Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at
# https://oss.oracle.com/licenses/upl.
#
# Description: Run by cloud-init at instance provisioning.
#   - install git
#   - install java 8 needed by SQLcl and Liquibase
#   - install SQLcl
#   - install Liquibase
#   - install Jenkins
#   - open port 8080 on the firewall

readonly PGM=$(basename $0)
readonly YUM_OPTS="-d1 -y"
readonly USER="opc"
readonly USER_HOME=$(eval echo ~${USER})

#######################################
# Print header
# Globals:
#   PGM
#######################################
echo_header() {
  echo "+++ ${PGM}: $@"
}

#######################################
# Install Git 
# Globals:
#   YUM_OPTS
#######################################
install_java() {
    echo_header "Install Git"
    yum install ${YUM_OPTS} git
    git --version
}

#######################################
# Install Java 
# Globals:
#   YUM_OPTS
#######################################
install_java() {
    echo_header "Install Java 8"
    yum install ${YUM_OPTS} --enablerepo=ol7_ociyum_config oci-included-release-el7
    yum install ${YUM_OPTS}  jdk1.8
    java --version
}

#######################################
# Install SQLcl
# Globals:
#   YUM_OPTS
#######################################
install_sqlcl() {
    echo_header "Install SQLcl"
    yum install ${YUM_OPTS} sqlcl
    alias sql="/opt/oracle/sqlcl/bin/sql"
    sql -v
}

#######################################
# Install Liqubase
# Globals:
#   USER_HOME
#######################################
install_liquibase() {
    wget https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.6.3/liquibase-3.6.3-bin.tar.gz
    mkdir /opt/liquibase
    tar xvzf liquibase-3.6.3-bin.tar.gz -C /opt/liquibase/
    echo 'export PATH=$PATH:/opt/liquibase' >> ${USER_HOME}.bashrc
    source ${USER_HOME}.bashrc
    liquibase --version
}

#######################################
# Install Jenkins
# Globals:
#   YUM_OPTS
#######################################
install_jenkins() {
    wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
    rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key
    yum install ${YUM_OPTS} jenkins

    systemctl start jenkins
    systemctl status jenkins
    systemctl enable jenkins
}

#######################################
# Configure Firewall
#######################################
configure_firewall() {
    echo_header "Configure Firewall"
    # local services="http https"
    # local service

    # for service in ${services}; do
    #     firewall-cmd --zone=public --add-service=${service}
    #     firewall-cmd --zone=public --add-service=${service} --permanent
    # done
    setenforce 0
    firewall-cmd --permanent --zone=public --add-port=8080/tcp
    firewall-cmd --reload
    setenforce 1
}

#######################################
# Main
#######################################
main
  yum update ${YUM_OPTS} 

  install_java
  install_sqlcl
  install_liquibase
  install_jenkins
  configure_firewall
}

main "$@"