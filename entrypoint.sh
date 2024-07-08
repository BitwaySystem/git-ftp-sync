#!/bin/bash

set -e

FTP_HOST=$1
FTP_USER=$2
FTP_PASS=$3
BRANCH=${4##*/}
EXTRACT_PATH=${5:-"/"}

# Configure the repository as safe
echo "Configuring Git safe directory..."
git config --global --add safe.directory /github/workspace

# Install necessary tools
echo "Installing necessary tools..."
apt-get update && apt-get install -y lftp sshpass
echo "Tools installed."

echo "Checking out branch $BRANCH..."
git checkout $BRANCH

echo "Fetching origin..."
git fetch origin

echo "Detecting commit range..."
if git rev-parse HEAD~1 >/dev/null 2>&1; then
  BEFORE_SHA=$(git rev-parse HEAD~1)
else
  BEFORE_SHA=$(git rev-parse HEAD)
fi
AFTER_SHA=$(git rev-parse HEAD)
echo "Before SHA: $BEFORE_SHA"
echo "After SHA: $AFTER_SHA"

if [ "$BEFORE_SHA" == "$AFTER_SHA" ]; then
  echo "First commit detected, archiving all files..."
  find . -type f | sed 's|^\./||' > changed_files.txt
else
  echo "Getting list of modified and deleted files..."
  git diff --name-only $BEFORE_SHA $AFTER_SHA > changed_files.txt
  git diff --diff-filter=D --name-only $BEFORE_SHA $AFTER_SHA > deleted_files.txt || touch deleted_files.txt
fi

echo "Files modified since last commit:"
cat changed_files.txt

echo "Files deleted since last commit:"
cat deleted_files.txt

if [ -s changed_files.txt ]; then
  echo "Filtering existing files..."
  grep -Fx -f <(find . -type f | sed 's|^\./||') changed_files.txt > existing_files.txt
  echo "Existing files to be archived:"
  cat existing_files.txt

  echo "Creating tar.gz archive of modified files..."
  tar -czf changed_files.tar.gz -T existing_files.txt
  echo "Archive created: changed_files.tar.gz"

  echo "Uploading tar.gz file to FTP server..."
  lftp -u $FTP_USER,$FTP_PASS -e "set ftp:ssl-force true; set ssl:verify-certificate false; put changed_files.tar.gz -o changed_files.tar.gz; bye" $FTP_HOST
  echo "File uploaded to FTP server."

  echo "Extracting tar.gz file on FTP server via SSH..."
  if [ "$EXTRACT_PATH" != "/" ]; then
    sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz -C $EXTRACT_PATH && rm -f changed_files.tar.gz"
  else
    sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz && rm -f changed_files.tar.gz"
  fi
  echo "Extraction completed on FTP server."
else
  echo "No modified files to archive and upload."
fi

if [ -s deleted_files.txt ]; then
  echo "Deleting files on FTP server..."
  sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST 'cat deleted_files.txt | xargs -I {} rm -f {}'
  echo "Deleted files on FTP server."
else
  echo "No files to delete on FTP server."
fi