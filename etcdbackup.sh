#!/bin/bash
sleep 10m
sudo apt install etcd-client -y
echo "ETCDCTL_API=3" >> /etc/environment
echo "ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt" >> /etc/environment
echo "ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt" >> /etc/environment
echo "ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key" >> /etc/environment
sudo etcdctl member list --endpoints=https://10.0.1.50:2379 
	
sudo etcdctl snapshot save /root/etcd.backup
sudo mv /root/etcd.backup /root/snapshot-$(date +%Y-%m-%d).db
	
