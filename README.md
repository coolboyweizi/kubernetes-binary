# 文件结构
```shell
├── node
│   ├── bin
│   ├── config
│   ├── logs
│   └── service
│       ├── kubelet.service
│       └── kube-proxy.service
├── README.md
├── scripts
│   └── ssl.sh
└── server
    ├── bin
    ├── config
    ├── logs
    └── service
        ├── kube-apiserver.service
        ├── kube-controller.service
        └── kube-scheduler.service
```
# 安装步骤
- 0、分别下载kubernetes的server和node二进制包
- 1、把文件夹拷贝到/opt/kubernetes/{server,node,script}
- 2、运行script/ssl.sh 生成相关证书以及搭建etcd服务
    + 该脚本通过ansible分发并批量执行
    + 运行前修改etcd的服务器分配
- 3、讲cni拷贝至/opt/cni。实现flannel网络
- 4、修改相关配置文件，并启动service下的服务
