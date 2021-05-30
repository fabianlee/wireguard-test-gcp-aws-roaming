#!/bin/bash
#
# Bootstrap script that creates service account for terraform, "tf-creator"
#
# if gcloud functions are slow, you may need to disable ipv6 temporarily
# permanent changes would need to go into /etc/sysctl.conf
# sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
# sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
#

path_to_gcloud=$(which gcloud)
if [ -z "$path_to_gcloud" ]; then
  echo "ERROR you must have gcloud installed to use this script, https://cloud.google.com/sdk/docs/install"
  exit 1
fi

# check if gcloud authentication exists
gcloud projects list >/dev/null 2>&1
loggedIn=($? -eq 0)
if [ $loggedIn -eq 0 ]; then
  loginAs=$(gcloud auth list 2>/dev/null | grep "*" | tr -d '/ //' | cut -c2-)
  echo "Already logged in as $loginAs"
else
  echo "ERROR not logged in.  Use 'gcloud auth login <accountName>'"
  exit 1
fi

if [ -z $1 ]; then
  project=$(gcloud config get-value project)
else
  project=$1
fi

# have project name, but need projectId
projectId=$(gcloud projects list --filter="name=$project" --format="csv(projectId)" | tail -n+2)
echo "project/projectId=$project/$projectId"
[ ! -z $projectId ] || { echo "ERROR could not lookup projectId for $project"; exit 3; }
gcloud config set project $projectId


# creates service account if one does not exist
function create_svc_account() {

  project="$1"
  name="$2"
  descrip="$3"

  accountExists=$(gcloud iam service-accounts list --filter="name ~ ${name}@" | wc -l)
  if [ $accountExists == 0 ]; then
    echo "Going to create service account '$name' in project $project"
    gcloud iam service-accounts create $name --display-name "$descrip" --project=$project
    echo "going to sleep for 30 seconds to wait for eventual consistency of service account creation..."
    sleep 30
  else
    echo "The service account $name is already created in project $project"
  fi

  # download key if just created or local json does not exist
  if [[ $accountExists == 0 || ! -f $name.json ]]; then
    svcEmail=$(get_email $project $name)
    echo "serviceAccountEmail: $svcEmail"
    keyCount=$(gcloud iam service-accounts keys list --iam-account $svcEmail | wc -l)

    # create key if necessary
    # normal count of lines is 2 (because output has header and gcp has its own managed key)
    if [ $keyCount -lt 3 ]; then
      echo "going to create/download key since key count is less than 3"
      gcloud iam service-accounts keys create $name.json --iam-account $svcEmail
    else
      echo "SKIP key download, there is already an existing key and it can only be downloaded upon creation"
      echo "delete the key manually from console.cloud.google.com if you need it rerecreated"
    fi

  fi

}

function get_email() {
  project="$1"
  name="$2"
  svcEmail=$(gcloud iam service-accounts list --project=$project --filter="name ~ ${name}@" --format="value(email)")
  echo $svcEmail
}

function assign_role() {
  project="$1"
  name="$2"
  roles="$3"

  svcEmail=$(get_email $project $name)
  echo "serviceAccountEmail: $svcEmail"

  savedIFS=$IFS
  IFS=' '
  for role in $roles; do
    set -ex
    gcloud projects add-iam-policy-binding $project --member=serviceAccount:$svcEmail --role=$role > /dev/null
    set +ex
  done
  IFS=$savedIFS

}

############## MAIN #########################################


create_svc_account $project "tf-creator" "terraform user"
# roles/iam.serviceAccountAdmin - to create other service accounts
# roles/compute.securityAdmin - for compute.firewalls.* (create)
# roles/compute.instanceAdmin - for compute.instances.* (create) and compute.disks.create
# roles/compute.networkAdmin - for compute.networks.* (create)
assign_role $project "tf-creator" "roles/iam.serviceAccountAdmin roles/resourcemanager.projectIamAdmin roles/storage.admin roles/compute.securityAdmin roles/compute.instanceAdmin roles/compute.networkAdmin"


