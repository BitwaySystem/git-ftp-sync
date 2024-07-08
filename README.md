# Git FTP Sync

This GitHub Action deploys and deletes files on an FTP server based on changes in a Git repository.

## Inputs

- `ftp_host`: FTP host (required)
- `ftp_user`: FTP user (required)
- `ftp_pass`: FTP password (required)
- `branch`: Branch name (required)
- `before_sha`: Previous commit SHA (required)
- `after_sha`: Current commit SHA (required)
- `extract_path`: Path to extract files on the FTP server (optional)

## Example Usage

```yaml
name: Deploy via FTP
on:
  push:
    branches:
      - develop
      - main

jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Fetch all history for all tags and branches
        run: git fetch --prune --unshallow

      - name: Set environment variables
        run: |
          echo "Setting environment variables based on the branch..."
          if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "Setting environment for develop branch"
            echo "FTP_HOST=${{ secrets.FTP_HOST_EXTRANET_QA }}" >> $GITHUB_ENV
            echo "FTP_USER=${{ secrets.FTP_USER_EXTRANET_QA }}" >> $GITHUB_ENV
            echo "FTP_PASS=${{ secrets.FTP_PASS_EXTRANET_QA }}" >> $GITHUB_ENV
            echo "DEPLOY_ENVIRONMENT=develop" >> $GITHUB_ENV
            echo "DEPLOY_LABEL=QA" >> $GITHUB_ENV
          elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "Setting environment for main branch"
            echo "FTP_HOST=${{ secrets.FTP_HOST_INTRANET_PD }}" >> $GITHUB_ENV
            echo "FTP_USER=${{ secrets.FTP_USER_INTRANET_PD }}" >> $GITHUB_ENV
            echo "FTP_PASS=${{ secrets.FTP_PASS_INTRANET_PD }}" >> $GITHUB_ENV
            echo "DEPLOY_ENVIRONMENT=main" >> $GITHUB_ENV
            echo "DEPLOY_LABEL=PD" >> $GITHUB_ENV
          fi
          echo "DISCORD_CHANNEL_URL=https://discord.com/api/v10/channels/1240006575092142263/messages" >> $GITHUB_ENV
          echo "DISCORD_BOT_TOKEN=${{ secrets.DISCORD_BOT_TOKEN_SECRET }}" >> $GITHUB_ENV
          echo "Environment variables set."

      - name: Deploy to FTP
        uses: <username>/git-ftp-sync@v1.0.0
        with:
          ftp_host: ${{ env.FTP_HOST }}
          ftp_user: ${{ env.FTP_USER }}
          ftp_pass: ${{ env.FTP_PASS }}
          branch: ${{ github.ref }}
          before_sha: ${{ github.event.before }}
          after_sha: ${{ github.sha }}
          extract_path: public_html

      - name: Capture list of commits
        run: |
          COMMIT_LIST=$(git log ${{ github.event.before }}..${{ github.sha }} --format='%h %s' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
          echo "COMMIT_LIST=${COMMIT_LIST}" >> $GITHUB_ENV

      - name: Send message to Discord
        run: |
          echo "Sending message and file to Discord..."
          MESSAGE_CONTENT=""
          TABLE_HEADER="Commit SHA | Mensagem\n--- | ---\n"
          if [ $GITHUB_REF = "refs/heads/main" ]; then
            BRANCH_TYPE="Produção (PD)"
          elif [ $GITHUB_REF = "refs/heads/develop" ]; then
            BRANCH_TYPE="Qualidade (QA)"
          fi
          MESSAGE_INTRO="Deploy para $BRANCH_TYPE foi bem-sucedido. Commits:"
          COMMIT_TABLE="$TABLE_HEADER$COMMIT_LIST"
          MESSAGE_CONTENT="$MESSAGE_INTRO\n\n$COMMIT_TABLE"
          curl -X POST -H "Authorization: Bot $DISCORD_BOT_TOKEN" -H "Content-Type: multipart/form-data" \
            -F "payload_json={\"content\": \"$MESSAGE_CONTENT\"}" \
            -F "file=@changed_files.tar.gz" \
            $DISCORD_CHANNEL_URL
          echo "Message and file sent to Discord."

      - name: Send error message to Discord
        if: failure()
        run: |
          ERROR_MESSAGE_CONTENT=""
          if [ $GITHUB_REF = "refs/heads/main" ]; then
            ERROR_MESSAGE_CONTENT="Erro no deploy para Produção (PD)."
          elif [ $GITHUB_REF = "refs/heads/develop" ]; então
            ERROR_MESSAGE_CONTENT="Erro no deploy para Qualidade (QA)."
          fi
          curl -X POST -H "Authorization: Bot $DISCORD_BOT_TOKEN" -H "Content-Type: application/json" \
            -d "{\"content\":\"$ERROR_MESSAGE_CONTENT\"}" \
            $DISCORD_CHANNEL_URL