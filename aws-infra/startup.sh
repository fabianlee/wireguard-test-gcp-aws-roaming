#!/bin/bash

echo this is from startup.sh | sudo tee /tmp/startup.log
curl http://169.254.169.254/latest/meta-data/local-ipv4 | sudo tee -a  /tmp/startup.log
