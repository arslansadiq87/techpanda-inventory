@echo off
title TechPanda Inventory - Deploy to Linux
cd /d "%~dp0"
python deploy_remote.py
pause

