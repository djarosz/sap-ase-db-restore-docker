#!/bin/bash

IMAGE_NAME=$1

if [ -z $IMAGE_NAME ]; then
	IMAGE_NAME=$(basename $(pwd))
fi

echo "gziping all backup files"

cd backups
for file in *; do 
	if file --mime-type "$file" | grep -q gzip$; then
		echo "$file is gzipped"
	else
		echo "$file is not gzipped ... compressing"
		gzip $file
	fi
done
cd -

echo "Building image $IMAGE_NAME"
docker build -t $IMAGE_NAME .
