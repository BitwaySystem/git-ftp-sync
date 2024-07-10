
# git-ftp-sync

Automate the upload of files via FTP from your GitHub repository using this GitHub Action. The `git-ftp-sync` checks for modified and deleted files since the last commit and syncs these changes with an FTP server. This script uses FTP for file upload and SSH for extraction, assuming the target server supports SSH.

## Inputs

- `ftp_host`: The FTP server host.
- `ftp_user`: The user for FTP authentication.
- `ftp_pass`: The password for FTP authentication.
- `branch`: The branch to be used for deployment.
- `extract_path`: (Optional) The path where the files will be extracted on the FTP server. The default is the root (`/`).

## Outputs

- `resume_deploy.tar.gz`: A file that contains information about the modified and deleted files during the deployment.

## Usage Example

Here is an example of how to use this GitHub Action in your workflow:

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
            echo "FTP_HOST=${{ secrets.FTP_HOST_QA }}" >> $GITHUB_ENV
            echo "FTP_USER=${{ secrets.FTP_USER_QA }}" >> $GITHUB_ENV
            echo "FTP_PASS=${{ secrets.FTP_PASS_QA }}" >> $GITHUB_ENV
          elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "FTP_HOST=${{ secrets.FTP_HOST_PD }}" >> $GITHUB_ENV
            echo "FTP_USER=${{ secrets.FTP_USER_PD }}" >> $GITHUB_ENV
            echo "FTP_PASS=${{ secrets.FTP_PASS_PD }}" >> $GITHUB_ENV
          fi
          echo "Environment variables set."

      - name: Deploy to FTP
        uses: BitwaySystem/git-ftp-sync@v1.0.0
        with:
          ftp_host: ${{ env.FTP_HOST }}
          ftp_user: ${{ env.FTP_USER }}
          ftp_pass: ${{ env.FTP_PASS }}
          branch: ${{ github.ref }}
          extract_path: "/"
```

## License

This project is licensed under the MIT License.