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
  git diff --name-only $BEFORE_SHA $AFTER_SHA >> changed_files.txt
  git diff --diff-filter=D --name-only $BEFORE_SHA $AFTER_SHA >> deleted_files.txt || true

  # Remove deleted files from changed files list
  if [ -s deleted_files.txt ]; then
    echo "Removing deleted files from changed files list..."
    grep -Fxv -f <(tail -n +2 deleted_files.txt) <(tail -n +2 changed_files.txt) > changed_files_filtered.txt || true
    echo "filename" > changed_files.txt
    cat changed_files_filtered.txt >> changed_files.txt
    rm changed_files_filtered.txt
  fi
fi

# Process deleted files
if [ $(wc -l < deleted_files.txt) -gt 1 ]; then
  echo "Files deleted since last commit:"
  tail -n +2 deleted_files.txt

  echo "Deleting files on FTP server..."
  sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST 'xargs -I {} rm -f {}' < <(tail -n +2 deleted_files.txt)
  if [ $? -eq 0 ]; then
    echo "Deleted files on FTP server."
  else
    echo "Error deleting files on FTP server."
    exit 1
  fi
else
  echo "No files to delete on FTP server."
fi

# Process modified files
if [ $(wc -l < changed_files.txt) -gt 1 ]; then
  echo "Files modified since last commit:"
  tail -n +2 changed_files.txt

  echo "Filtering existing files..."
  grep -Fx -f <(find . -type f | sed 's|^\./||') <(tail -n +2 changed_files.txt) > existing_files.txt
  echo "Existing files to be archived:"
  tail -n +2 existing_files.txt

  if [ $(wc -l < existing_files.txt) -gt 1 ]; then
    echo "Creating tar.gz archive of modified files..."
    tar -czf changed_files.tar.gz -T <(tail -n +2 existing_files.txt)
    if [ $? -eq 0 ]; then
      echo "Archive created: changed_files.tar.gz"
    else
      echo "Error creating tar.gz archive."
      exit 1
    fi

    echo "Uploading tar.gz file to FTP server..."
    lftp -u $FTP_USER,$FTP_PASS -e "set ftp:ssl-force true; set ssl:verify-certificate false; put changed_files.tar.gz -o changed_files.tar.gz; bye" $FTP_HOST
    if [ $? -eq 0 ]; then
      echo "File uploaded to FTP server."
    else
      echo "Error uploading file to FTP server."
      exit 1
    fi

    echo "Extracting tar.gz file on FTP server via SSH..."
    if [ "$EXTRACT_PATH" != "/" ]; then
      sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz -C $EXTRACT_PATH && rm -f changed_files.tar.gz"
    else
      sshpass -p $FTP_PASS ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $FTP_USER@$FTP_HOST "tar -xzf changed_files.tar.gz && rm -f changed_files.tar.gz"
    fi
    if [ $? -eq 0 ]; then
      echo "Extraction completed on FTP server."
    else
      echo "Error extracting tar.gz file on FTP server."
      exit 1
    fi
  else
    echo "No existing files to archive and upload."
  fi
else
  echo "No modified files to archive and upload."
fi

# Prepare report for Discord
echo "Preparing report for Discord..."
{
  echo "Modified files:"
  tail -n +2 changed_files.txt
  echo ""
  echo "Deleted files:"
  tail -n +2 deleted_files.txt
} > discord_report.txt
echo "Report prepared: discord_report.txt"