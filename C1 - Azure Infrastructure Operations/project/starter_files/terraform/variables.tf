variable resource_group_location {
  type        = string
  default     = "East US"
  description = "Location of the resource group"
}

variable resource_group_name {
  type        = string
  default     = "myResourceGroup"
  description = "Name of a resource group"
}

variable vm_count {
  type        = number
  default     = 2
  description = "The number of virtual machines created in the resource group"
}

variable username {
  type        = string
  default     = "tungnt40admin"
  description = "VM username"
}

variable password {
  type        = string
  default     = "Matkhaulan#1"
  description = "VM password"
}




