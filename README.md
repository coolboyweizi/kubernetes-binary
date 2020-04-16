├── node
│   ├── bin
│   ├── config
│   │   ├── bootstrap.kubeconfig
│   │   ├── kubelet.conf
│   │   ├── kubelet-config.yml
│   │   ├── kubelet.kubeconfig
│   │   ├── kube-proxy.conf
│   │   ├── kube-proxy.kubeconfig
│   │   └── kube-proxy.yml
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
    │   ├── kube-apiserver.conf
    │   ├── kube-controller.conf
    │   ├── kube-scheduler.conf
    │   └── token.csv
    ├── logs
    └── service
        ├── kube-apiserver.service
        ├── kube-controller.service
        └── kube-scheduler.service

