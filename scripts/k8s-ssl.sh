#!/usr/bin/env bash

# 使用cfssl创建etcd证书。将证书分发到相关服务的节点。etcd,node和server

# begin 设定相关变量 
ETCD_SSL_DIR=/opt/ssl


# 下载相关数据
test -x /usr/bin/cfssljson || wget http://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/bin/cfssljson
test -x /usr/bin/cfssl || wget http://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/bin/cfssl
test -x /usr/bin/cfssl-certinfo || wget http://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/bin/cfssl-certinfo
chmod +x /usr/bin/cfssl*

test -d $ETCD_SSL_DIR && echo "${ETCD_SSL_DIR} not empty" && exit 1
mkdir -p $ETCD_SSL_DIR && cd $ETCD_SSL_DIR

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

# 证书etcd配置信息
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

# kube-apiserver证书信息。 hosts需要设置可信任IP
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
		"172.27.0.1",
		"172.27.0.12",
		"172.27.0.7",
		"172.27.0.14"
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

# 证书自签
cfssl gencert -initca $ETCD_SSL_DIR/ca-csr.json | cfssljson -bare ca -

# 生成etcd证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www etcd-csr.json | cfssljson -bare server

# 生成api的证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www api-csr.json | cfssljson -bare api-server 

# 生成kube-proxy证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www kube-proxy-csr.json | cfssljson -bare kube-proxy 

