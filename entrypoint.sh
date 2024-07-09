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
apt-get update && apt-get install -y lftp sshpass git
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

# Prepare files with headers
echo "filename" > changed_files.txt
echo "deleted_file_nome_do_arquivo" > deleted_files.txt

if [ "$BEFORE_SHA" == "$AFTER_SHA" ]; then
  echo "First commit detected, archiving all files..."
  find . -type f | sed 's|^\./||' >> changed_files.txt
else
  echo "Getting list of modified and deleted files..."
  git diff --name-only --diff-filter=ACMRT $BEFORE_SHA $AFTER_SHA >> changed_files.txt
  git diff --diff-filter=D --name-only $BEFORE_SHA $AFTER_SHA >> deleted_files.txt || true
fi

# Process deleted files
if [ $(wc -l < deleted_files.txt) -gt 1 ]; then
  echo "Files deleted since last commit:"
  tail -n +2 deleted_files.txt > deleted_files_list.txt
  
  echo "Deleting files on FTP server..."
  while IFS= read -r file; do
    sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "rm -f $EXTRACT_PATH/$file"
  done < deleted_files_list.txt

  echo "Creating tar.gz archive of deleted files list..."
  tar -czf deleted_files_list.tar.gz deleted_files_list.txt
  rm deleted_files_list.txt
fi

# Process modified files
echo "Creating tar.gz archive of modified files..."
tar -czf changed_files.tar.gz -T <(tail -n +2 changed_files.txt)
if [ $? -eq 0 ]; then
  echo "Archive created: changed_files.tar.gz"
else
  echo "Error creating tar.gz archive."
  exit 1
fi

if [ -f changed_files.tar.gz ]; then
  echo "Uploading changed_files.tar.gz to FTP server..."
  lftp -u $FTP_USER,$FTP_PASS -e "set ftp:ssl-force true; set ssl:verify-certificate false; put changed_files.tar.gz -o changed_files.tar.gz; bye" $FTP_HOST
  if [ $? -eq 0 ]; then
    echo "File uploaded to FTP server."
  else
    echo "Error uploading file to FTP server."
    exit 1
  fi

  echo "Extracting changed_files.tar.gz on FTP server via SSH..."
  if [ "$EXTRACT_PATH" != "/" ]; then
    sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz -C $EXTRACT_PATH && rm -f changed_files.tar.gz"
  else
    sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz && rm -f changed_files.tar.gz"
  fi
  if [ $? -eq 0 ]; then
    echo "Extraction completed on FTP server."
  else
    echo "Error extracting changed_files.tar.gz on FTP server."
    exit 1
  fi
else
  echo "No modified files to archive and upload."
fi

# Prepare report for Discord
echo "Creating resume_deploy.tar.gz for Discord..."
if [ -f changed_files.tar.gz ] && [ -f deleted_files_list.tar.gz ]; then
  tar -czf resume_deploy.tar.gz changed_files.tar.gz deleted_files_list.tar.gz
elif [ -f changed_files.tar.gz ]; then
  tar -czf resume_deploy.tar.gz changed_files.tar.gz
elif [ -f deleted_files_list.tar.gz ]; then
  tar -czf resume_deploy.tar.gz deleted_files_list.tar.gz
else
  echo "No files to include in resume_deploy.tar.gz"
  exit 0
fi

# Clean up
rm -f changed_files.tar.gz deleted_files_list.tar.gz

echo "Report prepared: resume_deploy.tar.gz"