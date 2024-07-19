<?php

$platform = $argv[1] ?? false;
$secret = $argv[2] ?? false;

if (! $platform || ! $secret) {
    echo "Missing one or more arguments\n";

    exit(1);
}

if (! in_array($platform, ['github', 'gitlab', 'bitbucket'])) {
    echo "Invalid first argument, must be one of: github, gitlab, bitbucket\n";

    exit(1);
}

$baseDirectory = dirname(__FILE__, 3);

$releaseFilePath = match ($platform) {
    'github' => "$baseDirectory/release-zips/deploy-laravel-for-github-actions.zip",
    'gitlab' => "$baseDirectory/release-zips/deploy-laravel-for-gitlab-ci-cd.zip",
    'bitbucket' => "$baseDirectory/release-zips/deploy-laravel-for-bitbucket-pipelines.zip",
};

if (! is_file($releaseFilePath)) {
    echo "Release file does not exist, run the make-release.php script first\n";

    exit(1);
}

$curl = curl_init();

curl_setopt($curl, CURLOPT_URL, 'https://sjorso.com/new-deployment-script-release');

curl_setopt($curl, CURLOPT_POST, 1);

curl_setopt($curl, CURLOPT_POSTFIELDS, [
    'platform' => $platform,
    'hash' => file_get_contents("$releaseFilePath.hash"),
    'secret' => $secret,
    'release_zip_file' => curl_file_create($releaseFilePath),
]);

curl_setopt($curl, CURLOPT_HTTPHEADER, ['Accept: application/json']);

$result = curl_exec($curl);

$statusCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);

curl_close($curl);

if (! $result || $statusCode !== 200) {
    echo "Result was false and/or status code was not 200 (actual: $statusCode)\n";

    exit(1);
}
