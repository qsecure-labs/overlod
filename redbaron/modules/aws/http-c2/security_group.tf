data "external" "get_public_ip" {
  program = ["bash", "../../redbaron/data/scripts/get_public_ip.sh"]
}

resource "aws_security_group" "http-c2" {
  count = var.counter

  name        = "http-c2-${random_id.server[count.index].hex}"
  description = "Security group created by Overlord"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.get_public_ip.result["ip"]}/32"]
  }
  ingress { # rule for Starkiller
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["${data.external.get_public_ip.result["ip"]}/32"]
  }  
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

