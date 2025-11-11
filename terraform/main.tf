# main.tf for vSphere VM 

# Configure the vSphere
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

# --- Data Collection Service Host VM ---
resource "vsphere_virtual_machine" "data_collection_host" {
  name             = "${var.environment}-${var.client_id}-dcs-host"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder

  num_cpus = var.vm_cpu_count
  memory   = var.vm_memory_mb
  guest_id = data.vsphere_guest_os.os.id

  network_interface {
    network_id = data.vsphere_network.management_network.id
    adapter_type = data.vsphere_network.management_network.guest_nic_type
    network_id = data.vsphere_network.internal_data_network.id
    adapter_type = data.vsphere_network.internal_data_network.guest_nic_type
  }

  disk {
    label            = "disk0"
    size             = var.vm_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      linux_options {
        host_name = "${var.environment}-${var.client_id}-dcs-host"
        domain    = var.vm_domain
      }
      network_interface {
        ipv4_address = var.vm_ip_address
        ipv4_netmask = var.vm_netmask
      }
      ipv4_gateway = var.vm_gateway
      dns_server_list = var.vm_dns_servers
    }
  }

# provisioner remote
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y docker.io docker-compose", # Install Docker & Docker Compose
      "sudo usermod -aG docker ${var.ssh_user}",
      "echo 'Initial setup complete. Ready for app deployment via setup-environment.sh'"
    ]
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ip_address
    }
  }

  # Outputs
  output "vm_ip_address" {
    value = vsphere_virtual_machine.data_collection_host.default_ip_address
  }
}
