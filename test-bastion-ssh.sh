#!/bin/bash
#
# Uses ssh to test access to private vm instances via public bastion
#
# writes ~/.ssh/config so that proper keys are sent
# ssh through bastion with '-J'
#


function showMenu() {
  echo ""
  echo ""
  echo "== SSH TO =="
  echo ""
  echo "1) aws bastion instance $aws_bastion"
  echo "2) aws private instance 172.16.2.129"
  echo ""
  echo "3) gcp bastion instance $gcp_bastion"
  echo "4) gcp private instance 172.17.2.129"
  echo ""
}

function make_ssh_config() {
  aws_bastion="$1"
  gcp_bastion="$2"

  mkdir -p ~/.ssh
  sshconfig=~/.ssh/config
  [ -f $sshconfig ] || { echo "creating $sshconfig";touch $sshconfig; }

  if ! grep -q 172.16.2.129 $sshconfig; then
    cat <<EOF >> $sshconfig
Host 172.16.2.129
  IdentityFile $(pwd)/ansible_rsa
  StrictHostKeyChecking no
EOF
  fi

  if ! grep -q $aws_bastion $sshconfig && [ "$aws_bastion" != "na" ]; then
    cat <<EOF >> $sshconfig
Host $aws_bastion
  IdentityFile $(pwd)/ansible_rsa
  StrictHostKeyChecking no
EOF
  fi

  if ! grep -q 172.17.2.129 $sshconfig; then
    cat <<EOF >> $sshconfig
Host 172.17.2.129
  IdentityFile $(pwd)/ansible_rsa
  StrictHostKeyChecking no
EOF
  fi

  if ! grep -q $gcp_bastion $sshconfig && [ "$gcp_bastion" != "na" ]; then
    cat <<EOF >> $sshconfig
Host $gcp_bastion
  IdentityFile $(pwd)/ansible_rsa
  StrictHostKeyChecking no
EOF
  fi
}


######### MAIN ###################


# get output values for aws
cd aws-infra
theval=$(make output)
echo "$theval"
aws_bastion=$(echo "$theval" | grep aws-ubuntu-pub-wg_public_ip | awk -F'= ' '{print $2}' | tr -d '"')
[ -n "$aws_bastion" ] || { aws_bastion="na"; }
echo "aws_bastion is $aws_bastion"
cd ..

# get output values for gcp
cd gcp-infra
theval=$(make output)
echo "$theval"
gcp_bastion=$(echo "$theval" | grep gcp-ubuntu-pub-wg_public_ip | awk -F'= ' '{print $2}' | tr -d '"')
[ -n "$gcp_bastion" ] || { gcp_bastion="na"; }
echo "gcp_bastion is $gcp_bastion"
cd ..

# make ~/.ssh/config so ssh knows what keys to use
make_ssh_config "$aws_bastion" "$gcp_bastion"


echo "=================="
cat ~/.ssh/config

answer=""
while [ 1==1 ]; do

  showMenu
  test -t 0
  read -p "Which action (q to quit) ? " answer

  case $answer in
    1) 
      ssh ubuntu@${aws_bastion}
      ;;
    2) 
      ssh -J ubuntu@${aws_bastion}:22 ubuntu@172.16.2.129 -vvv
      ;;
    3) 
      ssh ubuntu@${gcp_bastion}
      ;;
    4) 
      ssh -J ubuntu@${gcp_bastion}:22 ubuntu@172.17.2.129 -vvv
      ;;
    q|quit|0)
      echo "QUITTING"
      exit 0
      ;;
    *)
      echo "ERROR unrecognized option, $answer"
      ;;
  esac

done


