terraform {
  required_version = ">=0.12"
}

// ****************************
// Generate a KMS key (for root block storage).
// ****************************

resource "aws_kms_key" "obsidian_root_block_kms" {
  description              = "Root block encryption KMS for Obsidian."
  deletion_window_in_days  = 7
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "RSA_4096"
  enable_key_rotation      = true

  tags = {
    Name        = "Obsidian"
    Domain      = "main.technology"
  }
}

// ****************************
// Create a VPC, subnet, internet gateway and a network interface for Obsidian
// ****************************

resource "aws_vpc" "obsidian_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "obsidian_subnet" {
  vpc_id            = aws_vpc.obsidian_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name        = "Obsidian"
    Domain      = "main.technology"
  }
}

resource "aws_internet_gateway" "obsidian_internet_gateway" {
  vpc_id = aws_vpc.obsidian_vpc.id

  tags = {
    Name  = "Obsidian"
    Domain = "main.technology"
  }
}

resource "aws_network_interface" "obsidian_network_interface" {
  subnet_id   = aws_subnet.obsidian_subnet.id
  private_ips = ["172.16.10.100"]

  tags = {
    Name        = "Obsidian"
    Domain      = "main.technology"
  }
}

// ****************************
// Attach elastic IP to the network interface
// ****************************

resource "aws_eip" "obsidian_elastic_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.obsidian_network_interface.id
  associate_with_private_ip = "172.16.10.100"

  depends_on = [aws_internet_gateway.obsidian_internet_gateway]
}

// ****************************
// Key pair for EC2.
// ****************************

resource "aws_key_pair" "obsidian_deployment_key_pair" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0JPeebH1UFORkc7V3ABy4MykGnd2Pre4iFskHmSRpEbFTU9D6DYwhoEwjN18znn2eD/jOplo/T3ZZM8IkSnlxFDQZFCq0NARncsrD60Ql/1PGdtjKsX7Yepjzxr3m4+deeewTdoV7jZNwTPoYvgl0AN6of4g82yw3zR84Lnf6YoZGIT+YR7MfaDGzo4SIxlN5EDtrv6XriUU4uDSinUs938Zpdrk/MEKtNCPGKqQJnYADiRJClm5tKiCmGlGzyBjrMjM3BKpfXQSjA29QRA23dHiylVtyMniupX2+3AYWNywUJUcqzpBsY1v7SZw0gr5Uta1bAjStO1hn9guC1OYA6AYaK9FhOTB3lOCXDVuR8bPPQbylpr8TMkOoqF6PKIB1ExvQWOxmntcJg4ZRUZRX5J0e7p6SquiUFfVd807cNfPMwFHYgBqUGbSRGf5CW/zRtyJsfRXhgUAJoO1XcjxxGhYd1V7kXPfLYj20qfTKVZvOcAKjazb01lsznwHqaPlINehwaMbod/p5OYBlRK5Y7AsLre46e6FZ0ZJ4/MhZgi15Qw9GwT2FDHo2VJaIeKM/4ZPn47SgCD+1swjH+nWH5I9aEVYaFnW8S1J1Td3SVHk6S+rQGCzWtmzrDpszeUidVl5YbJF4yGlXiMgo5CWj4P1doYgXiT2kuSFmuVL0ew== Obsidian AWS KP"
  key_name   = "obsidian_deployment_key"
}

// ****************************
// Create an EC2 instance of ubuntu 18.04 AMD64 server.
// ****************************

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name    = "name"
    values  = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name    = "virtualization-type"
    values  = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "obsidian" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.obsidian_root_block_kms.arn
  }

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.obsidian_network_interface.id
  }

  key_name = aws_key_pair.obsidian_deployment_key_pair.key_name

  tags = {
    Name        = "Obsidian"
    Domain      = "main.technology"
  }

  volume_tags = {
    Name   = "Obsidian"
    Domain = "main.technology"
  }
}
