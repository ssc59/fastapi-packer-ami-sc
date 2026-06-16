#!/bin/bash
set -e

echo "=== Starting AMI setup ==="

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker

# Start and enable Docker service
echo "Configuring Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to docker group
sudo usermod -a -G docker ec2-user

# Pull the Docker image
# This will be replaced by Packer variable
echo "Pulling Docker image: ${DOCKER_IMAGE}"
sudo docker pull ${DOCKER_IMAGE}

# Create systemd service to run container on boot
echo "Creating systemd service..."
sudo tee /etc/systemd/system/fastapi-app.service > /dev/null <<EOF
[Unit]
Description=FastAPI Application Container
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop fastapi-app
ExecStartPre=-/usr/bin/docker rm fastapi-app
ExecStart=/usr/bin/docker run --rm --name fastapi-app -p 80:8000 ${DOCKER_IMAGE}
ExecStop=/usr/bin/docker stop fastapi-app

[Install]
WantedBy=multi-user.target
EOF

# Enable the service (will start on boot)
sudo systemctl daemon-reload
sudo systemctl enable fastapi-app.service

# Clean up Docker images to reduce AMI size
echo "Cleaning up..."
sudo docker system prune -af

echo "=== AMI setup complete ==="
