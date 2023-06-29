#!/bin/bash

set -eu

# Set the following environment variables:
# DEPLOY_BUCKET = your bucket name
# DEPLOY_BUCKET_PREFIX = a directory prefix within your bucket
# DEPLOY_BRANCHES = regex of branches to deploy; leave blank for all
# DEPLOY_EXTENSIONS = whitespace-separated file exentions to deploy; leave blank for "jar war zip"
# AWS_ACCESS_KEY_ID = AWS access ID
# AWS_SECRET_ACCESS_KEY = AWS secret
# AWS_DEFAULT_REGION = AWS region
# AWS_SESSION_TOKEN = optional AWS session token for temp keys
# PURGE_OLDER_THAN_DAYS = Files in the .../deploy and .../pull-request prefixes in S3 older than this number of days will be deleted; leave blank for 90, 0 to disable.

if [[ -z "${DEPLOY_BUCKET}" ]]
then
    echo "Bucket not specified via \$DEPLOY_BUCKET"
fi

DEPLOY_BUCKET_PREFIX=${DEPLOY_BUCKET_PREFIX:-}

DEPLOY_BRANCHES=${DEPLOY_BRANCHES:-}

DEPLOY_EXTENSIONS=${DEPLOY_EXTENSIONS:-"jar war zip"}

PULL_REQUEST=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

PURGE_OLDER_THAN_DAYS=${PURGE_OLDER_THAN_DAYS:-"90"}


if [[ ! -z "$PULL_REQUEST" && "$PULL_REQUEST" != ""  && "$PULL_REQUEST" != "null" ]]
then
   target_path=pull-request/$PULL_REQUEST
elif [[ -z "$DEPLOY_BRANCHES" || "$BRANCH" =~ "$DEPLOY_BRANCHES" ]]
then
    echo "Deploying branch ${GITHUB_REF##*/}"

    BUILD_NUM=${GITHUB_RUN_NUMBER}
    if ! [[ -z "${BUILD_NUM_OFFSET:-}" ]]
    then
        BUILD_NUM=$((GITHUB_RUN_NUMBER+BUILD_NUM_OFFSET))
    fi

    target_path=deploy/${GITHUB_REF##*/}/$BUILD_NUM

else
    echo "Not deploying."
    exit

fi

discovered_files=""
for ext in ${DEPLOY_EXTENSIONS}
do
    discovered_files+=" $(ls $DEPLOY_SOURCE_DIR/*.${ext} 2>/dev/null || true)"
done

files=${DEPLOY_FILES:-$discovered_files}

if [[ -z "${files// }" ]]
then
    echo "Files not found; not deploying."
    exit
fi

target=builds/${DEPLOY_BUCKET_PREFIX}${DEPLOY_BUCKET_PREFIX:+/}$target_path/

if ! [ -x "$(command -v aws)" ]; then
    command -v pyenv && (pyenv global 3.7 || pyenv global 3.6 || true)
    pip install --upgrade --user -q awscli
    export PATH=~/.local/bin:$PATH
fi

aws s3api list-objects --bucket $DEPLOY_BUCKET --prefix $target --output=text | \
while read -r line
do
    filename=`echo "$line" | awk -F'\t' '{print $3}'`
    if [[ $filename != "" && $filename != "None" ]]    
    then
        echo "Deleting existing artifact s3://$DEPLOY_BUCKET/$filename."
        aws s3 rm s3://$DEPLOY_BUCKET/$filename
    fi
done

for file in $files
do
    echo "Deploying $file to s3://$DEPLOY_BUCKET/$target"
    aws s3 cp $file s3://$DEPLOY_BUCKET/$target
done

echo "PURGE_OLDER_THAN_DAYS ${PURGE_OLDER_THAN_DAYS}"
if [[ $PURGE_OLDER_THAN_DAYS -ge 1 ]]
then
    echo "Cleaning up builds in S3 older than $PURGE_OLDER_THAN_DAYS days . . ."

    cleanup_prefix=builds/${DEPLOY_BUCKET_PREFIX}${DEPLOY_BUCKET_PREFIX:+/}
    # TODO: this works with GNU date only
    older_than_ts=`date -d"-${PURGE_OLDER_THAN_DAYS} days" +%s`

    for suffix in deploy pull-request
    do
        # track number of items in the bucket to ensure we don't delete everything, which would break the _deploy servlet
        item_count=0
        echo "Getting number of items in $DEPLOY_BUCKET with prefix $cleanup_prefix$suffix/..."
        number_of_items=`aws s3api list-objects --bucket $DEPLOY_BUCKET --prefix $cleanup_prefix$suffix/ --output=json --query="length(Contents[])"` || number_of_items=0
        echo "$number_of_items items in $DEPLOY_BUCKET/$cleanup_prefix$suffix/..."
        
        aws s3api list-objects --bucket $DEPLOY_BUCKET --prefix $cleanup_prefix$suffix/ --output=text | \
        while read -r line
        do
            last_modified=`echo "$line" | awk -F'\t' '{print $4}'`
            if [[ -z $last_modified ]]
            then
                continue
            fi
            item_count=$((item_count+1))
            last_modified_ts=`date -d"$last_modified" +%s`
            filename=`echo "$line" | awk -F'\t' '{print $3}'`
            echo "File # $item_count: $filename. Last modified: $last_modified_ts"
            if [[ $last_modified_ts -lt $older_than_ts ]]
            then
                if [[ $filename != "" && "$item_count" -ne "$number_of_items" ]]
                then
                    echo "s3://$DEPLOY_BUCKET/$filename is older than $PURGE_OLDER_THAN_DAYS days ($last_modified). Deleting."
                    aws s3 rm "s3://$DEPLOY_BUCKET/$filename"
                elif [[ $filename != "" ]]
                then
                    echo "Skipping delete on s3://$DEPLOY_BUCKET/$filename to ensure at least one file in $DEPLOY_BUCKET."
                fi
            fi
        done
    done
fi
