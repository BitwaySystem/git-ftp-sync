#!/bin/bash

set -e

FTP_HOST=$FTP_HOST
FTP_USER=$FTP_USER
FTP_PASS=$FTP_PASS
BRANCH=$BRANCH
BEFORE_SHA=$BEFORE_SHA
AFTER_SHA=$AFTER_SHA
EXTRACT_PATH=${EXTRACT_PATH:-"."}

echo "Checking out branch $BRANCH..."
git checkout $BRANCH

echo "Fetching origin..."
git fetch origin

echo "Getting list of modified and deleted files..."
git diff --name-only $BEFORE_SHA $AFTER_SHA > changed_files.txt
git diff --diff-filter=D --name-only $BEFORE_SHA $AFTER_SHA > deleted_files.txt || touch deleted_files.txt

echo "Files modified since last commit:"
cat changed_files.txt

echo "Files deleted since last commit:"
cat deleted_files.txt

echo "Filtering existing files..."
grep -Fx -f <(find . -type f | sed 's|^\./||') changed_files.txt > existing_files.txt
echo "Existing files to be archived:"
cat existing_files.txt

echo "Creating tar.gz archive of modified files..."
tar -czf changed_files.tar.gz -T existing_files.txt
echo "Archive created: changed_files.tar.gz"

echo "Uploading tar.gz file to FTP server..."
lftp -u $FTP_USER,$FTP_PASS $FTP_HOST -e "set ftp:ssl-force true; set ssl:verify-certificate false; put changed_files.tar.gz -o changed_files.tar.gz; bye"
echo "File uploaded to FTP server."

if [ -n "$EXTRACT_PATH" ]; then
  echo "Extracting tar.gz file on FTP server via SSH..."
  sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz -C $EXTRACT_PATH && rm -f changed_files.tar.gz"
  echo "Extraction completed on FTP server."
fi

if [ -s deleted_files.txt ]; then
  echo "Deleting files on FTP server..."
  sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "cat deleted_files.txt | xargs -I {} rm -f {}"
  echo "Deleted files on FTP server."
else
  echo "No files to delete on FTP server."
fi