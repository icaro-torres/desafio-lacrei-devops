variable "project_name" {
  description = "Teste Devops Lacrei"
  type = string
  default = "lacrei-devops"
}

variable "instance_type" {
  description = "Tipo da instância"
  type = string
  default = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Caminho para a chave publica"
  type = string
  default = "~/.ssh/lacrei_key.pub"
}

variable "allowed_cidr_blocks" {
  description = "IPs permitidos para SSH"
  type = list(string)
  default = ["0.0.0.0/0"]
}