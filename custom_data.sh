#!/bin/bash
mkdir -P /home/ubuntu
echo 'git clone https://gist.github.com/26a439aefacff2054ca2ce81fd1a5c64.git' > /home/ubuntu/install.sh
echo 'sudo bash 26a439aefacff2054ca2ce81fd1a5c64/perfprep.sh' >> /home/ubuntu/install.sh
sudo bash /home/ubuntu/install.sh
