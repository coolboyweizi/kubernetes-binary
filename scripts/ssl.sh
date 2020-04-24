#!/usr/bin/env bash

# 证书目录
ETCD_SSL_DIR=/opt/ssl

# 服务器集群
node1_host='m1'
node1_ipaddr='192.168.199.11'

node2_host='n1'
node2_ipaddr='192.168.199.12'

node3_host='n2'
node3_ipaddr='192.168.199.13'

# 网卡
DEV=eth0

# 当前服务器信息与IP
HOSTNAME=`hostname`
IPADDR=`ifconfig | grep -n2 $DEV | grep inet | awk '{print $3}' | head -n1`

## 安装etcd服务
rm -rf /etc/etcd
rm -rf /var/lib/etcd
yum install etcd  -y

# 生成配置文件
cat <<EOF | tee /etc/etcd/etcd.conf
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://${IPADDR}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${IPADDR}:2379"
ETCD_NAME="${HOSTNAME}"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${IPADDR}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${IPADDR}:2379"
ETCD_INITIAL_CLUSTER="${node1_host}=https://${node1_ipaddr}:2380,${node2_host}=https://${node2_ipaddr}:2380,${node3_host}=https://${node3_ipaddr}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
#ETCD_STRICT_RECONFIG_CHECK="true"

#[Security]
ETCD_CERT_FILE="/opt/ssl/server.pem"
ETCD_KEY_FILE="/opt/ssl/server-key.pem"
ETCD_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/opt/ssl/server.pem"
ETCD_PEER_KEY_FILE="/opt/ssl/server-key.pem"
ETCD_PEER_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
EOF


# 三台同时启动ETCD
systemctl start etcd
systemctl enable etcd 


# 验证
ETCD_CTL=`which etcdctl`

echo $ETCD_CTL  --ca-file=/opt/ssl/ca.pem --cert-file=/opt/ssl/server.pem --key-file=/opt/ssl/server-key.pem \
				--endpoints=\""https://${node1_ipaddr}:2379,https://${node2_ipaddr}:2379,https://${node3_ipaddr}:2379"\" cluster-health | bash



