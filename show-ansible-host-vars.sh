#!/bin/bash

ansible -i ansible_inventory -m debug -a "var=hostvars[inventory_hostname]" $1

