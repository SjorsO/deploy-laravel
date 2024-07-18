<?php

$platform = $argv[1] ?? false;

if (! $platform) {
    echo "Missing first argument\n";

    exit(1);
}

if (! in_array($platform, ['github', 'gitlab', 'bitbucket'])) {
    echo "Invalid first argument, must be one of: github, gitlab, bitbucket\n";

    exit(1);
}

$baseDirectory = dirname(__FILE__, 2);

$buildDirectory = "$baseDirectory/releases/build";

if (is_dir($buildDirectory)) {
    shell_exec('rm -rf '.escapeshellarg($buildDirectory));
}

mkdir("$buildDirectory", recursive: true);

$relativeScriptDestinationDirectory = match ($platform) {
    'github' => '.github/deployment',
    'gitlab' => '.gitlab/deployment',
    'bitbucket' => '.bitbucket/deployment',
};

$scriptDestinationDirectory = "$buildDirectory/$relativeScriptDestinationDirectory";

mkdir($scriptDestinationDirectory, recursive: true);

shell_exec(sprintf(
    'cp -r %s %s',
    escapeshellarg("$baseDirectory/platforms/$platform/."),
    escapeshellarg($buildDirectory),
));

shell_exec(sprintf(
    'cp -r %s %s',
    escapeshellarg("$baseDirectory/script/."),
    escapeshellarg($scriptDestinationDirectory),
));

$files = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($buildDirectory)
);

[$prettyPlatformName, $styleError, $styleWarning, $styleReset] = match ($platform) {
    'github' => ['GitHub', '::error::', '::warning::', ''],
    // https://misc.flogisoft.com/bash/tip_colors_and_formatting
    'gitlab' => ['GitLab', '\e[101mError\e[0m\e[91m ', '\e[43mWarning\e[0m\e[93m ', '\e[0m'],
    'bitbucket' => ['Bitbucket', '', '', ''],
};

$hash = '';

/** @var SplFileInfo $file */
foreach ($files as $file) {
    if ($file->isDir()) {
        continue;
    }

    $filePath = $file->getPathname();

    $filePaths[] = $filePath;

    $contents = file_get_contents($filePath);

    $contents = str_replace('{PLATFORM}', $prettyPlatformName, $contents);
    $contents = str_replace('{SCRIPTS_DIR}', $relativeScriptDestinationDirectory, $contents);
    $contents = str_replace('{STYLE_ERROR}', $styleError, $contents);
    $contents = str_replace('{STYLE_WARNING}', $styleWarning, $contents);
    $contents = str_replace('{STYLE_RESET}', $styleReset, $contents);

    file_put_contents($filePath, $contents);

    $hash .= sha1_file($filePath);
}

$hash = sha1($hash);

$outputFilePath = match ($platform) {
    'github' => "$baseDirectory/releases/deploy-laravel-for-github-actions.zip",
    'gitlab' => "$baseDirectory/releases/deploy-laravel-for-gitlab-ci-cd.zip",
    'bitbucket' => "$baseDirectory/releases/deploy-laravel-for-bitbucket-pipelines.zip",
};

if (is_file($outputFilePath)) {
    unlink($outputFilePath);
}

if (is_file("$outputFilePath.hash")) {
    unlink("$outputFilePath.hash");
}

$zipOutput = shell_exec(sprintf(
    'cd %s && zip -r %s . -x __MACOSX -x ".DS_Store" -x "**/.DS_Store" -x "**/.gitkeep"',
    escapeshellarg($buildDirectory),
    escapeshellarg($outputFilePath),
));

file_put_contents("$outputFilePath.hash", $hash);

echo $zipOutput;

shell_exec('rm -rf '.escapeshellarg($buildDirectory));
