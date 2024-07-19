base_directory=$1
ssh_user=$2
ssh_host=$3
ssh_port=$4
private_ssh_key=$5
ssh_known_hosts=$6
php_executable=$7

if [[ -z "$ssh_user" ]]; then
    echo -e "::error::The variable \"\$ssh_user\" is not set."

    exit 1
fi

if [[ -z "$ssh_host" ]]; then
    echo -e "::error::The variable \"\$ssh_host\" is not set."

    exit 1
fi

if [[ -z "$ssh_port" ]]; then
    echo -e "::error::The variable \"\$ssh_port\" is not set."

    exit 1
fi

if [[ -z "$private_ssh_key" ]]; then
    echo -e "::error::The variable \"\$private_ssh_key\" is not set. Add this value as a secret to your GitHub repository."

    exit 1
elif [[ "$private_ssh_key" =~ ^ssh-rsa[[:blank:]] ]] || [[ "$private_ssh_key" =~ [[:blank:]]PUBLIC[[:blank:]]KEY ]]; then
    echo -e "::error::The variable \"\$private_ssh_key\" looks like a public key. It should be a private key."

    exit 1
fi

if [[ -z "$base_directory" ]]; then
    echo -e "::error::The variable \"\$base_directory\" is not set."

    exit 1
elif [[ "$base_directory" =~ /current/?$ ]]; then
    echo -e "::error::The variable \"\$base_directory\" points to the \"current\" directory. It should point one level higher to the base directory."

    exit 1
fi

if [[ -z "$php_executable" ]]; then
    php_executable="php"
fi

# Remove any trailing slash.
if [[ "$base_directory" =~ /$ ]]; then
    base_directory="${base_directory::-1}"
fi

echo "Preparing to connect to the remote server."

if [[ "$ssh_known_hosts" == "n/a" ]]; then
    # When using Bitbucket setting the known hosts is skipped. Bitbucket adds them automatically.
    :
elif [[ -n "$ssh_known_hosts" ]]; then
    mkdir -p ~/.ssh

    echo "$ssh_known_hosts" > ~/.ssh/known_hosts

    chmod 644 ~/.ssh/known_hosts
else
    echo -e "::warning::The variable \"\$ssh_known_hosts\" is not set. We will connect to the remote server without verifying the host."

    # Disable host key verification.
    echo "StrictHostKeyChecking no" | sudo tee -a /etc/ssh/ssh_config >/dev/null

    # Prevent related warnings.
    echo "LogLevel ERROR" | sudo tee -a /etc/ssh/ssh_config >/dev/null
fi

# Start the SSH agent.
eval "$(ssh-agent)" >/dev/null

# When using Bitbucket we can skip adding the ssh key. Bitbucket adds it automatically.
if [[ "$private_ssh_key" != "n/a" ]]; then
    # Add our key to the SSH agent.
    echo "$private_ssh_key" | tr -d "\r" | ssh-add -q - 2>/dev/null
fi

# Generate a unique file name for the deployment artifacts.
remote_artifacts_path="/tmp/deployment-artifacts-$(head -c 512 /dev/urandom | tr -dc 0-9a-f | head -c 8)"

echo "Uploading artifacts to the remote server."

scp -P "$ssh_port" "artifacts.tar.gz" "$ssh_user@[$ssh_host]:$remote_artifacts_path"

echo "Running the deployment script on the remote server."

ssh "$ssh_user@$ssh_host" -p "$ssh_port" "tar -xf $remote_artifacts_path .github/deployment/deploy.sh -O | bash -seo pipefail -- \"$remote_artifacts_path\" \"$base_directory\" \"$php_executable\""
