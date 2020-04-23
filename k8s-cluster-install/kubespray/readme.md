# https://github.com/kubernetes-sigs/kubespray

```bash
    git clone https://github.com/kubernetes-sigs/kubespray.git

    cd kubespray

    # Install dependencies from ``requirements.txt``
    sudo pip3 install -r requirements.txt

    # Copy ``inventory/sample`` as ``inventory/mycluster``
    cp -rfp inventory/sample inventory/mycluster

    # Update Ansible inventory file with inventory builder
    declare -a IPS=(10.10.1.3 10.10.1.4 10.10.1.5)
    CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

    # Review and change parameters under ``inventory/mycluster/group_vars``
    cat inventory/mycluster/group_vars/all/all.yml
    cat inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
```
# edit inventory.ini
uncomment to match your number of devices
```bash
[kube-master]
# node1
# node2

[etcd]
# node1
# node2
# node3

[kube-node]
# node2
# node3
```
# set networking edit inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml
```yaml
# Choose network plugin (cilium, calico, contiv, weave or flannel. Use cni for generic cni plugin)
# Can also be set to 'cloud', which lets the cloud provider setup appropriate routing
kube_network_plugin: flannel
calico
flannel
```
# edit cluster.yml playbook for centos7  ***LAB ONLY NOT FOR PRODUCTION***
prepend:
```yaml
- hosts: all
  gather_facts: false
  tasks:
    - name: be sure firewalld is disabled
      systemd: name=firewalld enabled=no
    
    - name: be sure firewalld is stopped
      systemd: name=firewalld state=stopped
      ignore_errors: yes
```
# firewall rules optional
``` yaml
# master
    - name: firewall master 6443
      firewalld:
        port: 6443/tcp
        permanent: yes
        state: enabled
    - name: firewall master 2379-2380
      firewalld:
        port: 2379-2380/tcp
        permanent: yes
        state: enabled
    - name: firewall master 10250-10252
      firewalld:
        port: 10250-10252/tcp
        permanent: yes
        state: enabled
    - name: firewall master 10255
      firewalld:
        port: 10255/tcp
        permanent: yes
        state: enabled
    - name: firewall master 8472
      firewalld:
        port: 8472/udp
        permanent: yes
        state: enabled
    - name: firewall master 30000-32767
      firewalld:
        port: 30000-32767/tcp
        permanent: yes
        state: enabled
    - name: firewall master masquerade
      firewalld:
        masquerade: yes
        state: enabled
        permanent: yes
    - name: restart firewall service
      systemd:
        state: restarted
        daemon_reload: yes
        name: firewalld
    # worker nodes
        - name: firewall worker 10250
      firewalld:
        port: 10250/tcp
        permanent: yes
        state: enabled
    - name: firewall worker 10255
      firewalld:
        port: 10255/tcp
        permanent: yes
        state: enabled
    - name: firewall worker 8472
      firewalld:
        port: 8472/udp
        permanent: yes
        state: enabled
    - name: firewall worker 30000-32767
      firewalld:
        port: 30000-32767/tcp
        permanent: yes
        state: enabled
    - name: firewall worker masquerade
      firewalld:
        masquerade: yes
        state: enabled
        permanent: yes
    - name: restart firewall service
      systemd:
        state: restarted
        daemon_reload: yes
        name: firewalld
```

# load your desired ssh key into eval
```bash

echo -n "Enter your ssh private key path ~/.ssh/id_rsa"
read sshkey
eval $(ssh-agent -s)
ssh-add $sshkey

# Deploy Kubespray with Ansible Playbook - run the playbook as root
# The option `--become` is required, as for example writing SSL keys in /etc/,
# installing packages and interacting with various systemd daemons.
# Without --become the playbook will fail to run!

ansible-playbook -i inventory/mycluster/hosts.yaml  --become --become-user=root --ask-become-pass cluster.yml

```
# if using a custom user
connect to the master and run
```bash
sudo cp /etc/kubernetes/admin.conf $HOME/ && sudo chown $(id -u):$(id -g) $HOME/admin.conf && export KUBECONFIG=$HOME/admin.conf
echo "export KUBECONFIG=$HOME/admin.conf" >> ~/.bashrc 
```

# auto complete

https://kubernetes.io/docs/tasks/tools/install-kubectl/

ubuntu:
```bash
sudo apt-get install bash-completion -y
echo 'source <(kubectl completion bash)' >>~/.bashrc
centos:
sudo yum install bash-completion -y
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
```
centos:
```bash
yum install bash-completion -y
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
```