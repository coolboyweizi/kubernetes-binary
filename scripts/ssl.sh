# 使用cfssl创建etcd与k8s证书
# 脚本是通过ansile推送
ETCD_SSL_DIR=/opt/ssl

# 预配置的信息与IP
node1_host='m1'
node1_ipaddr='192.168.199.11'

node2_host='m2'
node2_ipaddr='192.168.199.12'

node3_host='n1'
node3_ipaddr='192.168.199.13'

rm -rf $ETCD_SSL_DIR

# 下载相关执行脚本
if [ -x /usr/bin/ansible ];then

test -x /usr/bin/cfssljson || wget http://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/bin/cfssljson
test -x /usr/bin/cfssl || wget http://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/bin/cfssl
test -x /usr/bin/cfssl-certinfo || wget http://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/bin/cfssl-certinfo
chmod +x /usr/bin/cfssl*

mkdir -p $ETCD_SSL_DIR
cd $ETCD_SSL_DIR

# 自建证书授权中心配置信息
cat <<EOF  | tee ca-config.json
{
  "signing":{
    "default": {
      "expiry":"87600h"
    },
    "profiles": {
    "www":{
        "expiry":"87600h",
        "usages": [
        "singing",
          "key encipherment",
          "server auth",
          "client auth"
        ]
      }
    }
  }
}
EOF

# 自建证书授权中心的授权单位
cat <<EOF | tee ca-csr.json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "ca": {
    "expiry": "438000h"
  }
}
EOF


# 证书配置信息
cat <<EOF | tee etcd-csr.json
{
	"CN":"etcd",
	"hosts": [
		"${node1_ipaddr}",
		"${node2_ipaddr}",
		"${node3_ipaddr}"
	],
	"key": {
		"algo": "rsa",
		"size": 2048
	},
	"names": [
		{
			"C":"CN",
			"L":"Beijing",
			"ST":"Beijing"
		}
	]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

# 生成etcd证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www etcd-csr.json | cfssljson -bare server

# 第三方申请信息
cat <<EOF | tee kube-proxy-csr.json
{
	"CN":"system:kube-proxy",
	"hosts":[],
	"key":{
		"algo": "rsa",
		"size": 2048
	},
	"names":[{
		"C":"CN",
		"L":"Beijing",
		"ST":"Beijing",
		"O":"k8s",
		"OU":"system"
	}]
}
EOF

# 第三方申请证书信息
cat <<EOF | tee api-csr.json
{
	"CN":"kubernetes",
	"hosts":[
		"10.0.0.1",
		"127.0.0.1",
		"kubernetes",
		"kubernetes.default",
		"kubernetes.default.svc",
		"kubernetes.default.svc.cluster",
		"kubernetes.default.svc.cluster.local",
		"192.168.199.1",
		"192.168.199.11",
		"192.168.199.12",
		"192.168.199.13",
		"192.168.199.14",
		"192.168.199.15",
		"192.168.199.16",
		"192.168.199.17",
		"192.168.199.18",
		"192.168.199.19",
		"192.168.199.20"
	],
	"key":{
		"algo": "rsa",
		"size": 2048
	},
	"names":[{
		"C":"CN",
		"L":"Beijing",
		"ST":"Beijing",
		"O":"k8s",
		"OU":"system"
	}]
}
EOF


# 生成api的证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www api-csr.json | cfssljson -bare api-server

# 生成kube-proxy证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www kube-proxy-csr.json | cfssljson -bare kube-proxy



chmod 655 -R /opt/ssl
ansible all -m copy -a 'src=/opt/ssl dest=/opt'
fi

## 安装etcd服务
yum -y remove etcd
rm -rf /etc/etcd
rm -rf /var/lib/etcd

yum install etcd  -y

# 修改ETCD配置文件
# 当前服务器信息与IP
HOSTNAME=`hostname`
IPADDR=`ifconfig | grep -n2 ens33 | grep inet | awk '{print $3}' | head -n1`


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


if [ -x /usr/bin/ansible ];then

	# 启动ETCD. 以此
	ansible etcd -m systemd -a 'name=etcd state=started'

	# 验证
	ETCD_CTL=`which etcdctl`

	echo $ETCD_CTL --ca-file=/opt/ssl/ca.pem --cert-file=/opt/ssl/server.pem --key-file=/opt/ssl/server-key.pem \
	--endpoints=\""https://${node1_ipaddr}:2379,https://${node2_ipaddr}:2379,https://${node3_ipaddr}:2379"\" cluster-health | bash

fi

