#!/bin/bash

# start with template for inventory
cp ansible_inventory_template ansible_inventory

#  start with template for bastion hosts
cp group_vars/aws_bastion_template group_vars/aws_bastion
cp group_vars/gcp_bastion_template group_vars/gcp_bastion


# get output values for aws
cd aws-infra
theval=$(make output)
echo "$theval"
aws_bastion=$(echo "$theval" | grep aws-ubuntu-pub-wg_public_ip | awk -F'= ' '{print $2}' | tr -d '"')
[ -n "$aws_bastion" ] || { aws_bastion="na"; }
echo "aws_bastion is $aws_bastion"
cd ..

# replaces aws values
sed -i "s/{aws-ubuntu-pub-wg}/$aws_bastion/" ansible_inventory
sed -i "s/{aws-ubuntu-pub-wg}/$aws_bastion/" group_vars/aws_bastion



# get output values for gcp
cd gcp-infra
theval=$(make output)
echo "$theval"
gcp_bastion=$(echo "$theval" | grep gcp-ubuntu-pub-wg_public_ip | awk -F'= ' '{print $2}' | tr -d '"')
[ -n "$gcp_bastion" ] || { gcp_bastion="na"; }
echo "gcp_bastion is $gcp_bastion"
cd ..


# replaces gcp
sed -i "s/{gcp-ubuntu-pub-wg}/$gcp_bastion/" ansible_inventory
sed -i "s/{gcp-ubuntu-pub-wg}/$gcp_bastion/" group_vars/gcp_bastion
