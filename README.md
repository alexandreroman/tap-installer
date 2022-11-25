# Installing TAP with kubectl only

This is an experimental project: the goal is to install
[Tanzu Application Platform](https://tanzu.vmware.com/application-platform)
into your favorite Kubernetes cluster in 2 steps.

First you set some configuration parameters: Tanzu Network credentials,
registry configuration, etc.

Then you run the installation process with a single command:

```bash
kubectl apply -f tap-installer
```

That's all you need to do 🤯

The installation process takes care of everything, including downloading dependencies
from Tanzu Network such as
[Cluster Essentials](https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/)
and configuring TAP. No need to worry about CLI tools such as `tanzu`.

**Please note that this project is authored by a VMware employee under open source license terms.**

This is obviously not production ready!

## Contribute

Contributions are always welcome!

Feel free to open issues & send PR.

## License

Copyright &copy; 2022 [VMware, Inc. or its affiliates](https://vmware.com).

This project is licensed under the [Apache Software License version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
