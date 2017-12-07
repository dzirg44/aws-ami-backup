#!/bin/bash
SCRIPT_PATH=$(cd $(dirname $0) && pwd);

UTILS="utils.sh"

for util in $UTILS; do
  source $SCRIPT_PATH/$util
done
declare -a IMAGES

function show_help() {
e_header "Usage: ${0##*/} -b -d -t 14"
e_warning "be careful for use  in production!!!!!!"
cat << EOF
	-p         set your profile (if not set  - use "default)
        -b         backup instances
        -d         delete instances (optional)
        -t         time to delete (in day's)
        -l         list instances (show always  after delete)
        -h         this help
EOF
}

IDS=$(aws ec2   --profile "${PROFILE}" describe-instances --filter  "Name=instance-state-name,Values=running" 'Name=tag-key,Values=backup' 'Name=tag-value,Values=true' | jq '.Reservations[].Instances[].InstanceId'| sed s/\"//g)

####################################################################################################

########################################## BACKUP SECTION ##########################################
function backup_ami() {
INSTANCEID=$1
ecname=$(aws  --profile "${PROFILE}" --output text  ec2 describe-instances  --instance-ids $INSTANCEID --query 'Reservations[].Instances[].[Tags[?Key==`Name`] | [0].Value]')

if [ -n "$ecname" ]; then
  imageid=$(aws   --profile "${PROFILE}" ec2 --output text create-image --no-reboot  --instance-id $INSTANCEID --name "$ecname-$SHORTDATE" --description "$ecname $SHORTDATE")
  IMAGES+=($imageid)
fi
}
function backup_ec2(){
for id in $IDS; do
  e_arrow "backup instance id: $id"
  backup_ami $id
done
}

########################################## DELETE SECTION ##########################################
function delete_ec2(){
#TIMEINSECONDS="500"
aws ec2 --profile "${PROFILE}" describe-images --owners self --output json |  jq -c '.Images[]' | while read i; do
createdate=$(echo $i | jq  -M '.CreationDate' | sed s/\"//g)
imagename=$(echo $i | jq  -M '.Name' | sed s/\"//g)
imageid=$(echo $i | jq  -M '.ImageId' | sed s/\"//g)

retention_diff_tmp=$(echo $(($(("$EPOCHDATE" - $(date -d "$createdate" "+%s"))))))
if [ $retention_diff_tmp -ge $TIMEINSECONDS ]; then
  $SCRIPT_PATH/delete.sh d $imageid $PROFILE
fi
done
list_ec2
}

####################################################################################################

########################################## CHECK SECTION ##########################################

function check_in_images(){
image=$1
for k in "${IMAGES[@]}"; do
      if [ "$image" == "$k" ] ; then
        return 0
      fi
done
return 1
}

function list_ec2(){
alength=${#IMAGES[@]}
if  [ -n "$delete" ] ;then
  sleep 180
fi
cdate="0"
aws ec2  --profile "${PROFILE}" describe-images --owners self --output json |  jq -c '.Images[]' | while read i; do
createdate=$(echo $i | jq  -M '.CreationDate' | sed s/\"//g)
imagename=$(echo $i | jq  -M '.Name' | sed s/\"//g)
imageid=$(echo $i | jq  -M '.ImageId' | sed s/\"//g)
if [ $alength -gt 0 ];then
      if  check_in_images $imageid; then
	outprint="e_success"
       else
        outprint="e_warning2"
      fi
else
   retention_diff=$(echo $(($(($(date -d "$SHORTDATE" "+%s") - $(date -d "$createdate" "+%s"))) / 86400)))
      if [ $retention_diff -eq $cdate ]; then
        outprint="e_success"
       else 
        outprint="e_warning2"
      fi
fi
 e_note "=============$imagename=============="
 $outprint "Image_name: $imagename"
 $outprint "Created_date: $createdate"
 $outprint "Image_id: $imageid"
done
}

function main(){
	if [ "$list" == "1" ] ; then
	  list_ec2
	fi

	if [ -n "$backup" ] ; then
	  backup_ec2
	fi

	if [ -n "$delete" ]; then
	  delete_ec2
	fi

}
while getopts "br:dr:t:lr:p:h" opt; do
        case "$opt" in
                b)        backup="1"
                        ;;
                d)        delete="1"
                        ;;
                t)        tdate=$OPTARG
                        ;;
                l)        list="1"
                        ;;
                p)        profile=$OPTARG
                        ;;

                h)        show_help
                          exit 0
                        ;;
                '?')
                             exit 1
                        ;;
        esac
done
if [ -z $profile ]; then
  e_error  "please select your profile (use \"default\" if you have one profile)"
  exit 1
fi
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi
shift "$((OPTIND-1))"
PROFILE="$profile"
if [ -z $tdate ]; then
  TIMEINSECONDS=$((86400 * 7))
else 
  TIMEINSECONDS=$((86400 * $tdate))
fi
main


