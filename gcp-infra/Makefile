THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform

apply: init 
	$(TF) apply -auto-approve
	$(TF) output

init: create-keypair
	## skips init if .terraform directory already exists
	[ -d .$(TF) ] || $(TF) init

## public/private keypair for ssh
create-keypair:
	[ -f ../ansible_rsa ] || { echo "ERROR, generate ansible_rsa keypair"; exit 1; }
	[ -f tf-creator.json ] || { echo "ERROR, create gcp service account 'tf-creator'"; exit 1; }

destroy:
	@echo "destroying compute instances first, which avoids errors due to timing"
	$(TF) destroy -target google_compute_instance.web -target google_compute_instance.wgserver -force -auto-approve
	@echo "waiting 60 seconds for vm instance deletion..."
	sleep 60
	$(TF) destroy -force -auto-approve
	ssh-keygen -f ~/.ssh/known_hosts -R 172.17.2.129
	##rm terraform.tfstate*

refresh:
	$(TF) refresh

output:
	$(TF) output
