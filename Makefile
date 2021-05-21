THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform14

## have terraform create infrastructure
apply: create-keypair serviceaccount-prereq
	cd aws-infra && make
	cd gcp-infra && make

## output variables from build
output:
	cd aws-infra && make output
	cd gcp-infra && make output

## public/private keypair for ssh login to vms
create-keypair:
	[ -f ansible_rsa ] || ssh-keygen -t rsa -b 4096 -f ansible_rsa -C $(PROJECT) -N "" -q

## prerequisite service account keys needed for terraform
serviceaccount-prereq:
	[ -f gcp-infra/tf-creator.json ] || { echo "ERROR, need to generate gcp service account key first"; exit 1; }
	[ -f ~/.aws/credentials ] || { echo "ERROR, create aws config file with access key and secret at ~/.aws/credentials"; exit 1; }

## get ready for ansible by writing ansible inventory, ansible group vars for bastions
get-ansible-ready:
	./populate-ansible-ssh.sh

## test Ansible ability to get to bastion, then internal vm via bastion
test-ansible:
	@echo "==Test AWS bastion and internal vm"
	ansible -m ping aws-ubuntu-pub-wg
	ansible -m ping aws-ubuntu-priv-web
	@echo "==Test GCP bastion and internal vm"
	ansible -m ping gcp-ubuntu-pub-wg
	ansible -m ping gcp-ubuntu-priv-web 

## test ssh to bastion and internal vm
test-ssh:
	./test-bastion-ssh.sh

## installs wireguard and apache across public and private vms on gcp and aws
ansible-run:
	ansible-playbook playbook-wireguard.yml
