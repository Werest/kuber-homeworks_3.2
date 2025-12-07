# Создание сети
resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

# Создание подсети
resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  zone           = var.yc_default_zone
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Группа безопасности для K8s
resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.k8s_network.id
  description = "Security group for Kubernetes cluster"

  # SSH доступ
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd client API
  ingress {
    protocol       = "TCP"
    port           = 2379
    v4_cidr_blocks = ["192.168.10.0/24"]
  }

  # etcd peer API
  ingress {
    protocol       = "TCP"
    port           = 2380
    v4_cidr_blocks = ["192.168.10.0/24"]
  }

  # Kubelet API
  ingress {
    protocol       = "TCP"
    port           = 10250
    v4_cidr_blocks = ["192.168.10.0/24"]
  }

  # NodePort Services
  ingress {
    protocol       = "TCP"
    port           = 31000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Весь трафик внутри подсети
  ingress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["192.168.10.0/24"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание сервисного аккаунта
resource "yandex_iam_service_account" "k8s_sa" {
  name = "k8s-service-account"
}

# Назначение роли сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# Master node
resource "yandex_compute_instance" "master" {
  name               = var.master_node.name
  platform_id        = var.master_node.platform_id
  zone               = var.yc_default_zone
  
  resources {
    cores  = var.master_node.cores
    memory = var.master_node.memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.master_node.disk_size
      type     = var.type_hardware
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
    user-data = data.template_file.cloudinit.rendered
  }

  scheduling_policy {
    preemptible = true
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(replace(var.ssh_public_key, ".pub", ""))
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "./scripts/install-k8s-master.sh"
    destination = "/tmp/install-k8s-master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-k8s-master.sh",
      "sudo /tmp/install-k8s-master.sh ${var.k8s_version}",
    ]
  }
}

# Worker nodes
resource "yandex_compute_instance" "workers" {
  count = length(var.worker_nodes)

  name               = var.worker_nodes[count.index].name
  platform_id        = var.worker_nodes[count.index].platform_id
  zone               = var.yc_default_zone
  
  resources {
    cores  = var.worker_nodes[count.index].cores
    memory = var.worker_nodes[count.index].memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.worker_nodes[count.index].disk_size
      type     = var.type_hardware
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
    user-data = data.template_file.cloudinit.rendered
  }

  scheduling_policy {
    preemptible = true
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(replace(var.ssh_public_key, ".pub", ""))
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "./scripts/install-k8s-worker.sh"
    destination = "/tmp/install-k8s-worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-k8s-worker.sh",
      "sudo /tmp/install-k8s-worker.sh",
    ]
  }
}

data "template_file" "cloudinit" {
  template = file("./templates/cloud-init.yml")
  vars = {
    "ssh_public_key" = file(var.ssh_public_key)
  }
}