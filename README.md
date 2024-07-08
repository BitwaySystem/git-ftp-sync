
# git-ftp-sync
Automatize o envio de arquivos via FTP do seu repositório GitHub usando este GitHub Action. O `git-ftp-sync` verifica os arquivos modificados e deletados desde o último commit e sincroniza essas mudanças com um servidor FTP. Este script utiliza FTP para upload dos arquivos e SSH para extração, assumindo que o servidor de destino suporte SSH.

## Inputs

- `ftp_host`: O host do servidor FTP.
- `ftp_user`: O usuário para autenticação FTP.
- `ftp_pass`: A senha para autenticação FTP.
- `branch`: O branch a ser usado para o deploy.
- `extract_path`: (Opcional) O caminho onde os arquivos serão extraídos no servidor FTP. O padrão é a raiz (`/`).

## Outputs

Nenhum.

## Exemplo de Uso

Aqui está um exemplo de como usar este GitHub Action em seu workflow:

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