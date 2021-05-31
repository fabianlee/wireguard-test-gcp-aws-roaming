#!/bin/bash
#
# Uses ssh to test access to private vm instances via public bastion
#
# writes ~/.ssh/config so that proper keys are sent
# ssh through bastion with '-J'
#

# site test sends pre-canned commands to each host
# instead of interactive ssh
siteTestFlag="$1"
if [ "--site2site" == "$siteTestFlag" ]; then
  site_test=1
else
  site_test=0
fi
echo "site_test = $site_test"


function showMenu() {
  echo ""
  echo ""
  if [ $site_test -eq 0 ]; then
    echo "== SSH TO =="
  else
    echo "== SITE TEST =="
  fi
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

curl_options="--fail --connect-timeout 3 --retry 0 -sS"
curl_all_aws="curl $curl_options http://172.16.1.10; curl $curl_options http://172.16.2.129"
curl_all_gcp="curl $curl_options http://172.17.1.10; curl $curl_options http://172.17.2.129"

answer=""
while [ 1==1 ]; do

  showMenu
  test -t 0
  read -p "Which action (q to quit) ? " answer

  case $answer in
    1) 
      if [ $site_test -eq 0 ]; then
        ssh ubuntu@${aws_bastion}
      else
        ssh ubuntu@${aws_bastion} "$curl_all_aws ; $curl_all_gcp"
      fi
      ;;
    2) 
      if [ $site_test -eq 0 ]; then
        ssh -J ubuntu@${aws_bastion}:22 ubuntu@172.16.2.129 -vvv
      else
        ssh -J ubuntu@${aws_bastion}:22 ubuntu@172.16.2.129 "$curl_all_aws ; $curl_all_gcp"
      fi
      ;;
    3) 
      if [ $site_test -eq 0 ]; then
        ssh ubuntu@${gcp_bastion}
      else
        ssh ubuntu@${gcp_bastion} "$curl_all_gcp ; $curl_all_aws"
      fi
      ;;
    4) 
      if [ $site_test -eq 0 ]; then
        ssh -J ubuntu@${gcp_bastion}:22 ubuntu@172.17.2.129 -vvv
      else
        ssh -J ubuntu@${gcp_bastion}:22 ubuntu@172.17.2.129 "$curl_all_gcp ; $curl_all_aws"
      fi
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


