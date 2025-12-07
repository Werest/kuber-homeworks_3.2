terraform {
  required_version = ">=1.5"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95"
    }
  }
}

provider "yandex" {

  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_default_zone
  # token                    = "do not use!!!"
  service_account_key_file = file("~/authorized_key.json")
}