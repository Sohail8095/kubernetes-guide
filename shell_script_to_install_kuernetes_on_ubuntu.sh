#!/bin/bash

#Kubernetes installation on Ubuntu
# $1=ip addess of slave VM
# $2 = ip of pod network (for calico = 192.168.0.0/16 )

#Be as a root user
sudo su -
cd ..

apt-get update -y

#keep the swap memory off
if [ -f /proc/swaps ]; then
	swapoff -a
else
	echo "No swap found"
fi

#Add the hostname to the server
if [ -f /etc/hostname ]; then
	sed -i "s/.*/kmaster/g" /etc/hostname
else
	echo "No file found"
fi

if [ -d /u01/k8s ]; then 
	echo "Directory is there"
else
	mkdir -p /u01/k8s
fi

export HOME=/u01/k8s
echo $HOME

#To add a hostname and IP address for better connection

echo "To get the IP address"
export HOST_NAME=$(hostname -i)

echo hostname: $HOST_NAME

#Insert the IP address in hosts file

if [ -f /etc/hosts ]; then
	sed -i "2ikmaster ${HOST_NAME}" /etc/hosts
else
	echo "No file found"
fi

#Create ssh connection between master and slave for better communication

echo "Creating an ssh connection between master and slave"
ssh-keygen -t rsa -f $HOME/.ssh/id_rsa

#Send the public key from master to slave
ssh-copy-id -i ~/.ssh/id_rsa.pub root@$1

echo "########## Strating the Installation of Kubernetes #########"

echo "Installing Docker"

#Install openssh server
apt-get install openssh-server

# Install Docker CE
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install apt-transport-https ca-certificates curl software-properties-common -y

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

## Install Docker CE.
apt-get update && apt-get install docker-ce=18.06.2~ce~3-0~ubuntu -y

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

#Create the directories
mkdir -p /etc/systemd/system/docker.service.d

#Reload daemon
systemctl daemon-reload

#Restart docker
systemctl restart docker

echo "+++++++ Kubernetes Installation ++++++++"

#Install the communication dependencies
apt-get update && apt-get install -y apt-transport-https curl -y

#Add the key
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

#Add the content in the file
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

#Now update the repository
apt-get update

echo "------ Installing the main components -------"
#The kubectl, kubelet and kubeadm
apt-get install -y kubelet kubeadm kubectl


#Kubernetes will start to work

echo "Initializing kubernetes as a master"

kubeadm init --pod-network-cidr=$2 --apiserver-advertise-address=$HOST_NAME >> master_key.log

#Create Useful directories
mkdir -p $HOME/.kube

#Copy the files
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

#Give the ownership to directories
sudo chown $(id -u):$(id -g) $HOME/.kube/config
