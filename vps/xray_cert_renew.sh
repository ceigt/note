#!/bin/bash

/home/user/.acme.sh/acme.sh --install-cert -d www.example.com --ecc --fullchain-file /path/to/example.crt --key-file /path/to/example.key
echo "Certificates Renewed"

chmod +r /path/to/example.key
echo "Read Permission Granted for Private Key"

sudo systemctl restart xray
echo "Xray Restarted"

sudo systemctl restart nginx
echo "Nginx Restarted"
