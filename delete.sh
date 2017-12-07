#!/bin/bash
SCRIPT_PATH=$(cd $(dirname $0) && pwd);
UTILS="utils.sh"

for util in $UTILS; do
  source $SCRIPT_PATH/$util
done

if [ $1 == "d" ]; then
action="delete"
fi

DELETEID=$2
PROFILE=$3


if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws is not installed.' >&2
  exit 1
fi

function delete_ami() {
  deleteImage=$DELETEID
e_arrow "DELETE image id: $DELETEID on profile: $PROFILE"

  deleteSnapshot=$(aws ec2 describe-images --image-ids $deleteImage --profile "${PROFILE}" --query "Images[*].BlockDeviceMappings[*].Ebs.SnapshotId")

  tmpResult=1
  if [ "" = "$deleteImage" ]; then
    echo " delete Image is empty "
  else
	  deleteResponce=$(aws ec2 deregister-image --image-id ${deleteImage} --profile "${PROFILE}")
    if [ "$deleteResponce" = "true" ]; then
      tmpResult=0

      deleteSnapResponce=$(aws ec2 delete-snapshot --snapshot-id $deleteSnapshot --profile "${PROFILE}")
        if [ "$deleteSnapResponce" = "true" ]; then
          tmpResult=0
        fi
    fi
  fi
  if [ $tmpResult -eq 1 ]; then
    resultDelete="failure"
  fi
}

function main() {
if [ "$action"  == "delete" ]; then
  delete_ami
fi

}
main
