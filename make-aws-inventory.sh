#!/bin/bash

terraform14 output | grep ec2_web_instance_ip_address | awk '{print $3}' | tr -d '"'
