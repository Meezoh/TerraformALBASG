#!/bin/bash
apt-get update -y
apt-get install -y openjdk-17-jre

# Add Jenkins Repository and Key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install and Start Jenkins
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins
