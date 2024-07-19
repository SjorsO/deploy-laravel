# Deploy Laravel
Production-ready zero-downtime deployment script for Laravel.

## Install
Visit the link below for the download and the installation guide:
- [Deploy Laravel for GitHub Actions](https://sjorso.com/deploy-laravel/github/step-1)
- [Deploy Laravel for GitLab CI/CD](https://sjorso.com/deploy-laravel/gitlab/step-1)
- [Deploy Laravel for Bitbucket Pipelines](https://sjorso.com/deploy-laravel/bitbucket/step-1)

Requirements:
- Laravel 5 or higher
- Ubuntu 16.04 or higher / CentOS7 or higher

Installing this deployment script can typically be done in less than 10 minutes.
Make sure you follow the installation guide linked above, it helps you configure the script and it prevents any pitfalls (like the pitfall of having stored user uploaded files in the public directory). 

## Features
This deployment script follows all [deployment best practices](https://sjorso.com/laravel-deployment-best-practices) (except running your tests).
A quick overview:
- CI/CD starts running when you push a new commit to the main branch
- CI/CD builds and bundles your application
- The bundle is uploaded to your server
- When everything is ready the new release is activated (zero-downtime)
- Laravel's optimization commands are run by the [before](https://github.com/SjorsO/deploy-laravel/blob/main/src/script/hooks/before-activation.sh) and [after](https://github.com/SjorsO/deploy-laravel/blob/main/src/script/hooks/after-activation.sh) activation hooks.
- File permissions are set correctly for the new release (if necessary)
- [OPCache is flushed](https://github.com/SjorsO/deploy-laravel/blob/main/src/script/hooks/flush-opcache.sh) by calling `opcache_reset()` 

## Migrating from a different way of deploying
This deployment script is compatible with Deployer and Laravel Envoyer.
If you have already deployed your application with Deployer or Laravel Envoyer then you can switch to this deployment script without making any changes.

If your application has already been deployed with git clone, FTP or Laravel Forge quick deploy, then you only have to change your Apache2/Nginx webroot from `public` to `current/public`.
How to make this change is explained in the installation guide.
