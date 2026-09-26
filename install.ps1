#!/bin/bash
# Selfunnel Windows Installer (PowerShell)
irm https://selfunnel.ru/install.ps1?token=%1 | iex

# Usage:
#   irm https://selfunnel.ru/install.ps1 | iex          # с запросом токена
#   .\install.ps1 YOUR_TOKEN                             # с токеном сразу
