###cloud vars
variable "yc_cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
  default = "b1g5lq99m43jv5mpei89"
}

variable "yc_folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
  default = "b1g88k8r3li6sb89l14s"
}

variable "yc_default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}
# variable "default_cidr" {
#   type        = list(string)
#   default     = ["10.0.1.0/24"]
#   description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
# }

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "image_id" {
  description = "Image ID for VM"
  type = string
  default = "fd8bnguet48kpk4ovt1u"
}

variable "type_hardware" {
  description = "Type Hardware for VM"
  type = string
  default = "network-hdd"
}

variable "k8s_version" {
  description = "k8s version"
  type        = string
  default     = "1.28"
}

variable "master_node" {
  description = "Master node config"
  type = object({
    name        = string
    platform_id = string
    cores       = number
    memory      = number
    disk_size   = number
  })
  default = {
    name        = "k8s-master"
    platform_id = "standard-v2"
    cores       = 4
    memory      = 8
    disk_size   = 50
  }
}

variable "worker_nodes" {
  description = "Worker nodes config"
  type = list(object({
    name        = string
    platform_id = string
    cores       = number
    memory      = number
    disk_size   = number
  }))
  default = [
    {
      name        = "k8s-worker-1"
      platform_id = "standard-v2"
      cores       = 4
      memory      = 8
      disk_size   = 50
    },
    {
      name        = "k8s-worker-2"
      platform_id = "standard-v2"
      cores       = 4
      memory      = 8
      disk_size   = 50
    },
    {
      name        = "k8s-worker-3"
      platform_id = "standard-v2"
      cores       = 4
      memory      = 8
      disk_size   = 50
    },
    {
      name        = "k8s-worker-4"
      platform_id = "standard-v2"
      cores       = 4
      memory      = 8
      disk_size   = 50
    }
  ]
}