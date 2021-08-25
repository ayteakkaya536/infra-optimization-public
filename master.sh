#!/bin/bash

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update ; clear
sudo apt-get install -y docker-ce
sudo service docker start ; clear
sudo echo '{ "exec-opts": ["native.cgroupdriver=systemd"] }' >> /etc/docker/daemon.json  # this is required to match dokcer and kubernetes driver
sudo systemctl restart docker ; clear


sudo echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update ; clear
sudo apt-get install -y kubelet kubeadm kubectl	

yes | sudo kubeadm init 

# below is required to give permissions to root user for kubernetes
sudo mkdir -p /root/.kube # $HOME
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config # $HOME
sudo chown 0:0 /root/.kube/config # $HOME  #$(id -u):$(id -g)

# Weave network
yes | sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

#below sends kubernetes join command to worker node
ssh -i "main-key.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@10.0.1.51  /bin/bash << EOF
  #echo "sudo $(kubeadm token create --print-join-command)"
  echo '#!/bin/bash ' > results.sh
  echo "sudo $(kubeadm token create --print-join-command)" >> results.sh
  chmod 777 results.sh
  ./results.sh
  
EOF

#below sends kubernetes join command to worker node
ssh -i "main-key.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@10.0.1.52  /bin/bash << EOF
  #echo "sudo $(kubeadm token create --print-join-command)"
  echo '#!/bin/bash ' > results.sh
  echo "sudo $(kubeadm token create --print-join-command)" >> results.sh
  chmod 777 results.sh
  ./results.sh
  
EOF

## test hba run
#sudo kubectl apply -f dep-ser-hpa.yml
##test sql-wordpress run
sudo kubectl apply -k ./
sudo chmod 777 etcdbackup.sh
./etcdbackup.sh
sudo apt install apache2-utils -y
