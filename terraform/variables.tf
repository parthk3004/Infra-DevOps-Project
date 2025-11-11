
variable "vsphere_user" {
  description = "The vSphere username."
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "The vSphere password."
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "The vCenter server FQDN or IP."
  type        = string
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow unverified SSL certificates for vSphere connection."
  type        = bool
  default     = false
}

variable "vm_template_name" {
  description = "The name of the VM template to clone."
  type        = string
}

variable "vm_folder" {
  description = "The vSphere folder to deploy the VM into."
  type        = string
}

variable "vm_cpu_count" {
  description = "Number of vCPUs for the VM."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Memory in MB for the VM."
  type        = number
  default     = 2048 # 2GB
}

variable "vm_disk_gb" {
  description = "Disk size in GB for the VM."
  type        = number
  default     = 50
}

variable "vm_ip_address" {
  description = "Static IP address for the VM."
  type        = string
}

variable "vm_netmask" {
  description = "Network mask for the VM."
  type        = string
}

variable "vm_gateway" {
  description = "Default gateway for the VM."
  type        = string
}

variable "vm_dns_servers" {
  description = "List of DNS servers for the VM."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"] # Example
}

variable "vm_domain" {
  description = "Domain name for the VM."
  type        = string
  default     = "local"
}

variable "environment" {
  description = "Deployment environment (e.g., staging, production)."
  type        = string
}

variable "client_id" {
  description = "Unique identifier for the client."
  type        = string
}

variable "ssh_user" {
  description = "SSH user for remote-exec provisioning."
  type        = string
  default     = "ubuntu" # Common for Ubuntu templates
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for remote-exec."
  type        = string
}
