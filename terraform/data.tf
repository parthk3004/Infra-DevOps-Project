#to fetch secrets and config at run time

data "vsphere_datacenter" "dc" {
  name = "parth_db" 
}

data "vsphere_datastore" "datastore" {
  name          = "db1" 
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "parth_resource_pool" 
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "management_network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_guest_os" "os" {
  name = "ubuntu64Guest"
}
