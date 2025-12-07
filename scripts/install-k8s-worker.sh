#!/bin/bash

# Версия Kubernetes
K8S_VERSION="1.34"

# Выход при ошибке
set -e

# Функция ожидания освобождения блокировки APT
wait_for_apt() {
    echo "Проверка блокировки APT..."
    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ||
          sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ||
          sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Жду освобождения блокировки APT (процесс: $(sudo lsof -t /var/lib/apt/lists/lock 2>/dev/null || echo 'unknown'))..."
        sleep 5
    done
}

echo "=== Отключаем swap ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "=== Загружаем модули ядра ==="
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== Настраиваем sysctl ==="
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "=== Устанавливаем containerd ==="

wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gpg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y containerd.io

echo "=== Настраиваем containerd ==="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Устанавливаем kubeadm, kubelet ==="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y kubelet kubeadm
sudo apt-mark hold kubelet kubeadm

echo "=== Настройка завершена! ==="