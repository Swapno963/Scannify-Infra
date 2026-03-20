# Scannify-Infra

### Full-Stack Deployment with Terraform

This repository contains Terraform configurations to deploy a full-stack application on AWS, including:

- **React** frontend
- **Node.js** backend
- **AWS RDS** (PostgreSQL)

## Features

- Infrastructure as Code using Terraform
- EC2 instance provisioning for backend and frontend
- RDS database setup with proper networking and security groups
- Configurable via Terraform variables

## Prerequisites

- Terraform v1.5+ installed
- AWS CLI configured with access key, secret key, and region
- Node.js and React app ready for deployment

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Swapno963/Scannify-Infra.git
   cd Scannify-Infra
   ```


2. Install Terraform
    ```bash
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
    ```


3. Install AWS CLI
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```

4. Apply Changes
    ```bash
    terraform init
    terraform apply
    ```
