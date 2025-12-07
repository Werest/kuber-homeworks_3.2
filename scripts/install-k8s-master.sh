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
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== Настраиваем sysctl ==="
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "=== Устанавливаем containerd ==="

# Ожидаем освобождения APT
wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Устанавливаем репозиторий Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y containerd.io

echo "=== Настраиваем containerd ==="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Проверяем containerd ==="
sudo systemctl status containerd --no-pager || true
sudo ctr version || true

echo "=== Устанавливаем kubeadm, kubelet, kubectl ==="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

wait_for_apt
sudo apt-get update

wait_for_apt
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "=== Ждем инициализации kubelet ==="
sleep 10
sudo systemctl status kubelet --no-pager || true

echo "=== Инициализируем кластер ==="
# Получаем IP-адрес
API_SERVER_IP=$(hostname -I | awk '{print $1}')
echo "API Server IP: ${API_SERVER_IP}"

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${API_SERVER_IP} \
  --cri-socket=unix:///var/run/containerd/containerd.sock \
  --upload-certs \
  --control-plane-endpoint=${API_SERVER_IP}

echo "=== Настраиваем kubectl ==="
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "=== Устанавливаем CNI Flannel ==="
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "=== Ждем запуска PODов ==="
sleep 30
kubectl get pods --all-namespaces

echo "=== Генерируем join-команду ==="
sudo kubeadm token create --print-join-command > /tmp/kubeadm-join.sh
chmod +x /tmp/kubeadm-join.sh

echo "=== Готово! ==="
echo "Join command:"
cat /tmp/kubeadm-join.sh