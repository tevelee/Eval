#!/bin/bash

openssl aes-256-cbc -K $encrypted_f50468713ad3_key -iv $encrypted_f50468713ad3_iv -in github_rsa.enc -out github_rsa -d
chmod 600 github_rsa
ssh-add github_rsa
ssh -o StrictHostKeyChecking=no git@github.com || true
git config --global user.email tevelee@gmail.com
git config --global user.name 'Travis CI'
