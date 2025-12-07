output "master_node_public_ip" {
  description = "Public IP address of the master node"
  value       = yandex_compute_instance.master.network_interface[0].nat_ip_address
}

output "master_node_internal_ip" {
  description = "Internal IP address of the master node"
  value       = yandex_compute_instance.master.network_interface[0].ip_address
}

output "worker_nodes_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = [for vm in yandex_compute_instance.workers : vm.network_interface[0].nat_ip_address]
}

output "worker_nodes_internal_ips" {
  description = "Internal IP addresses of worker nodes"
  value       = [for vm in yandex_compute_instance.workers : vm.network_interface[0].ip_address]
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "ssh -i ${replace(var.ssh_public_key, ".pub", "")} ubuntu@${yandex_compute_instance.master.network_interface[0].nat_ip_address} 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig.yaml"
}