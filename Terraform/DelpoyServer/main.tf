provider "aws" {
  region = "ap-south-1"
}

# Variable to control instance action
variable "instance_action" {
  description = "Action to perform on the EC2 instance (start or stop)"
  type        = string
  default     = "start"  # Options: "start" or "stop"
}

resource "random_string" "suffix" {
  length = 4
  special = false
}

# Security group to allow SSH and HTTP
resource "aws_security_group" "app_sg" {
  name        = "allow_http_ssh_${random_string.suffix.result}"
  description = "Allow HTTP and SSH access"


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "app_server" {
  ami           = "ami-0dee22c13ea7a9a67"
  instance_type = "t3.micro"
  key_name      = "KEY"

  tags = {
    Name = "DockerAppServer"
  }

  vpc_security_group_ids = [aws_security_group.app_sg.id]
}

resource "null_resource" "manage_instance_state" {
  triggers = {
    action = var.instance_action
  }

  provisioner "local-exec" {
    command = "aws ec2 ${var.instance_action}-instances --instance-ids ${aws_instance.app_server.id}"
    environment = {
      AWS_DEFAULT_REGION = "ap-south-1"
    }
  }

  depends_on = [aws_instance.app_server]
}



# Output the public IP of the instance
output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

