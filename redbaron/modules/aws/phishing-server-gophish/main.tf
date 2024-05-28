data "aws_region" "current" {
}

resource "random_id" "server" {
  count       = var.counter
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  count     = var.counter
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "gophish-server" {
  count      = var.counter
  key_name   = "gophish-server-key-${random_id.server[count.index].hex}"
  public_key = tls_private_key.ssh[count.index].public_key_openssh
}

resource "aws_instance" "gophish-server" {
  count = var.counter

  tags = {
    Name = "gophish-server-${random_id.server[count.index].hex}"
  }

  ami                         = var.amis[data.aws_region.current.name]
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.gophish-server[count.index].key_name
  vpc_security_group_ids      = [aws_security_group.gophish-server[count.index].id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.ssh[count.index].private_key_pem}\" > ssh_keys/${self.public_ip} && echo \"${tls_private_key.ssh[count.index].public_key_openssh}\" > ssh_keys/${self.public_ip}.pub && chmod 400 ssh_keys/*"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ssh_keys/${self.public_ip}*"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }

  provisioner "remote-exec" {
    scripts = concat(["../../redbaron/data/scripts/core_deps.sh"], var.install)

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }

  provisioner "file" {
    source      = "../../redbaron/data/scripts/gophish.sh"
    destination = "/tmp/gophish_install.sh"
    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 777 /tmp/gophish_install.sh",
      "sudo /tmp/gophish_install.sh",
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh[count.index].private_key_pem
    }
  }
}

data "template_file" "ssh_config" {
  count = var.counter

  template = file("../../redbaron/data/templates/ssh_config.tpl")

  depends_on = [aws_instance.gophish-server]

  vars = {
    name         = "gophish_${aws_instance.gophish-server[count.index].public_ip}"
    hostname     = aws_instance.gophish-server[count.index].public_ip
    user         = "ubuntu"
    identityfile = "${abspath(path.root)}/ssh_keys/${aws_instance.gophish-server[count.index].public_ip}"
  }
}

resource "null_resource" "gen_ssh_config" {
  count = var.counter

  triggers = {
    template_rendered = data.template_file.ssh_config[count.index].rendered
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.ssh_config[count.index].rendered}' > ssh_configs/config_${random_id.server[count.index].hex}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ssh_configs/config_${random_id.server[count.index].hex}"
  }
}

