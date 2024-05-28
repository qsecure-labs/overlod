variable "subnet_id" {
}

variable "vpc_id" {
}

variable "counter" {
  default = 1
}

variable "instance_type" {
  default = "t2.micro"
}

variable "install" {
  type    = list(string)
  default = []
}

variable "amis" {
  type = map(string)
  default = {
    "eu-west-1" = "ami-0f56955469757e5aa"
  }
}

