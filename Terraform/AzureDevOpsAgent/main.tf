provider "aws" {
  region = "ap-south-1"
}

# Variable to control instance action
variable "instance_action" {
  description = "Action to perform on the EC2 instance (start or stop)"
  type        = string
  default     = "start"  # Options: "start" or "stop"
}

# Variable to store the Personal Access Token (PAT) securely
variable "azure_devops_pat" {
  description = "Personal Access Token for Azure DevOps"
  type        = string
  sensitive   = true
}

# Security group to allow SSH and HTTP
resource "aws_security_group" "app_sg" {
  name        = "allow_http_ssh"
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

# EC2 instance configured as an Azure DevOps agent
resource "aws_instance" "app_server" {
  ami           = "ami-0dee22c13ea7a9a67"  # Update with your preferred AMI ID
  instance_type = "t3.micro"
  key_name      = "KEY"  # Replace with your key pair name

  tags = {
    Name = "AzurePipelineAgent-EC2"
  }

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # User data to install and configure the Azure DevOps agent
  user_data = <<-EOF
    #!/bin/bash
    # Install dependencies
    sudo apt update -y
    sudo apt install -y curl jq

    # Download and configure the Azure DevOps agent
    mkdir myagent && cd myagent
    curl -O "https://vstsagentpackage.azureedge.net/agent/3.246.0/vsts-agent-linux-x64-3.246.0.tar.gz"
    tar zxvf "vsts-agent-linux-x64-3.246.0.tar.gz"

    # Configure the agent with PAT variable
    ./config.sh --unattended \\
      --url https://dev.azure.com/mirzadismail \\
      --auth pat \\
      --token "${var.azure_devops_pat}" \\
      --pool Docker-App \\
      --agent AzurePipelineAgent-EC2

    # Install and start the agent as a service
    sudo ./svc.sh install
    sudo ./svc.sh start
  EOF
}

# Null resource to manage instance start/stop based on action
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

