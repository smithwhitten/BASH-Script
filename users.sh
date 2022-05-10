#!/bin/bash

MINIO=/usr/bin/mc
NOW=`date +%Y%m%d%H%M%S`

while getopts a:r:b:u:p: flag
do
	case "${flag}" in
		a) action=${OPTARG};;
		r) remote=${OPTARG};;
		b) bucket=${OPTARG};;
		u) user=${OPTARG};;
		p) pass=${OPTARG};;
	esac
done

if [ -z "$action" ]
then
	echo "Please specify an action."
	exit 1
fi

if [ -z "$remote" ]
then
	echo "Please specify a valid remote."
	exit 1
fi

# Create bucket with user and policy
create () {
	USERNAME=$user
	PASSWORD=$pass

	if [ -z "$bucket" ]
	then
		echo "Please specify a valid bucket."
		exit 1
	fi

	if [ -z "$USERNAME" ]
	then
		# Blank username, generate one
		USERNAME=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 16 | head -n 1)
	fi

	if [ -z "$PASSWORD" ]
	then
		# Blank password, generate one
		PASSWORD=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 32 | head -n 1)
	fi

	# Create policy
	POLICYNAME="${USERNAME}-${bucket}-rw-${NOW}"
	POLICYFILE="${POLICYNAME}.json"

	# Create bucket
	$MINIO mb $remote/$bucket

	# Create policy file
	cat > $POLICYFILE << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${bucket}/*"
      ],
      "Sid": ""
    }
  ]
}
EOF

	# Create user
	$MINIO admin user add $remote $USERNAME $PASSWORD

	# Create policy
	$MINIO admin policy add $remote $POLICYNAME $POLICYFILE
	$MINIO admin policy set $remote $POLICYNAME user=$USERNAME

	# Delete policy file
	rm -f $POLICYFILE

	# Done
	echo "Bucket ${bucket} assigned to ${USERNAME} with password ${PASSWORD}."
	exit 0
}

# Drop user and policy
drop () {
	if [ -z "$user" ]
	then
		echo "Please specify a valid user."
		exit 1
	fi

	# Get policy
	POLICY=`${MINIO} admin user info ${remote} ${user} | grep PolicyName: | cut -d ' ' -f 2`
	if [ -z "$POLICY" ]
	then
		echo "Could not detect policy. Delete it manually."
	else
		$MINIO admin policy remove $remote $POLICY
	fi

	# Delete user
	$MINIO admin user remove $remote $user

	# Done
	echo "User and policy deleted. Bucket retained. To remove, run ${MINIO} rb <remote>/<bucket-name>."
	exit 0
}

if [ "$action" = "create" ]
then
	create
	exit $?
elif [ "$action" = "drop" ]
then
	drop
	exit $?
else
	echo "Invalid action: ${action}"
	exit 1
fi
