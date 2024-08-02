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

## Migrating to this deployment script
This deployment script is compatible with Deployer and Laravel Envoyer.
If you have already deployed your application with Deployer or Laravel Envoyer then you can switch to this deployment script without making any changes.

If your application has already been deployed with git clone, FTP or Laravel Forge quick deploy, then you only have to change your Apache2/Nginx webroot from `public` to `current/public`.
How to make this change is explained in the installation guide.

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

## Zero-downtime deployments (current & releases directory)
This deployment script is zero-downtime, this has two big advantages: deployments don't cause downtime for your users, and deployments are gracefully aborted when something goes wrong.
To understand what exactly this means, lets first look at what it means if your deployments are not zero-downtime.

A typical not zero-downtime deployment strategy is SSHing into your server, calling `git clone`, and then running `composer install`.
While these commands are running your application is in limbo: some code is new, some code is old, and some new dependencies are missing entirely.
A user visiting your application while this deployment is running will most likely receive a 500 error.
Even worse, if the `composer install` fails then you have to scramble to roll back the `git clone` you already did.

This deployment script solves these problems by using the following directory structure:

```
project
├── .env
├── current/ (your nginx/apache2 webroot)
├── releases/
│   ├── 1/ (old release, unused)
│   ├── 2/ (old release, unused)
│   └── 3/ (the latest release, symlinked to the "current" directory)
└── storage/
```

Nginx/Apache2 is serving your application from the "current" directory.
This directory is a symlink to the latest release directory.
This deployment script creates a new release directory for each deployment, but it does not change the symlink until that release is completely ready.

Using a new release directory for each deployment means that a running deployment does not affect your current application at all.
Even if a step in the deployment script fails, the new release directory will simply get deleted and your application keeps running like before.

Once the new release is completely ready the new release is [symlinked to the "current" directory](https://github.com/SjorsO/deploy-laravel/blob/fd6ddaf5a6562db60c4c1711c66ef76e142213df/src/script/deploy.sh#L166-L169).
Changing the symlink is instant, also causing no downtime for your users.
