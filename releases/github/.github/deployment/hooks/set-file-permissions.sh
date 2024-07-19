# This hook makes sure that your application won't get any file permission errors.
#
# To learn more, visit: https://sjorso.com/laravel-file-permissions

php_executable=$1
new_release_directory=$2

on_exit() {
    script_status_code=$?

    if [[ "$script_status_code" -ne 0 ]]; then
        echo -e "::warning::For more information about file permissions, please visit: https://sjorso.com/laravel-file-permissions"

        echo -e "::warning::Setting file permissions is optional. You can disable this hook by commenting out the \"set-file-permissions.sh\" hook in \"deploy.sh\". However, if you disable this hook you might run into file permission errors in the future."
    fi

    # Exit this trap with the original status code.
    exit "$script_status_code"
}
# This "trap" command will call the "on_exit" function when we exit this script.
trap on_exit INT EXIT TERM

deployment_user=$(whoami)

# This line of code was taken from DeployerPHP (https://github.com/deployphp/deployer/blob/784e7b7b3160c6a61166f915532546fe811ac17d/recipe/deploy/writable.php)
http_user=$(ps axo comm,user | grep -E "[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx" | grep -v root | sort | awk '{print $NF}' | uniq | head -n1)

if [[ -z "$http_user" ]]; then
    echo -e "::error::Could not detect which user serves web requests. You must manually set the \"\$http_user\" variable in the \"set-file-permissions\" hook."

    exit 1
fi

# We only have to change file permissions if you are using two different users. We don't have to make
# any changes if the user that runs this deployment is the same user that serves web requests.
if [[ "$deployment_user" == "$http_user" ]]; then
    echo "We don't have to change any file permissions."

    exit 0
fi

if [[ -z "$(command -v "setfacl")" ]]; then
    echo -e "::error::We need \"setfacl\" to properly set file permissions, but it is not installed. You can install it using \"sudo apt install acl\"."

    exit 1
fi

http_user_group=$(id -Gn "$http_user")

if [[ $(wc -w <<< "$http_user_group") != "1" ]]; then
    echo -e "::error::Can not set file permissions. The \"$http_user\" user belongs to multiple groups, we can't decide which group we should use. You must manually set the \"\$http_user_group\" variable in the \"set-file-permissions\" hook. User \"$http_user\" belongs to these groups: $http_user_group"

    exit 1
fi

if ! id -nG "$deployment_user" | grep -q "\b$http_user_group\b"; then
    echo -e "::error::Can not set file permissions. The \"$deployment_user\" user should be in the \"$http_user_group\" group. You can do this using \"sudo usermod -aG $http_user_group $deployment_user\"."

    exit 1
fi

filesystems_config_permission_1=$("$php_executable" artisan tinker --execute "echo decoct(config('filesystems.disks.local.permissions.dir.public'))")
filesystems_config_permission_2=$("$php_executable" artisan tinker --execute "echo decoct(config('filesystems.disks.public.permissions.dir.public'))")

if [[ "$filesystems_config_permission_1" != "775" ]] || [[ "$filesystems_config_permission_2" != "775" ]]; then
    echo -e "::error::You must set the default directory permissions to 0775 in your \"filesystems.php\" config file. This must be done for both the \"local\" disk and the \"public\" disk. With the current setting you will get file permission errors. Make sure you set them to 0775, not 775."

    exit 1
fi

echo "Making newly deployed code writeable for both \"$deployment_user\" and \"$http_user\"."

# We only set file permissions for the "storage" directory if it doesn't contain any files yet. If
# it already contains files, and the current file permissions are incorrect, then we can't change
# them without "sudo".
if [[ $(find -L "$new_release_directory/storage" -type f -print -quit | wc -l) -eq 0 ]]; then
    echo "Also making the storage directory writeable for both \"$deployment_user\" and \"$http_user\"."

    # The "-L" option makes "find" traverse into our symlinked storage directory.
    set_storage_directory_permissions="-L"
else
    set_storage_directory_permissions=""
fi

chmod 2775 "$new_release_directory"

# Loop over all files.
find $set_storage_directory_permissions "$new_release_directory" -type f -not -path "$new_release_directory/vendor/*" -print0 | while read -rd $'\0' file_path
do
    chmod 664 "$file_path"

    chown "$deployment_user":"$http_user_group" "$file_path"
done

# Loop over all directories.
find $set_storage_directory_permissions "$new_release_directory" -type d -not -path "$new_release_directory/vendor/*" -print0 | while read -rd $'\0' directory_path
do
    chmod 2775 "$directory_path"

    chown "$deployment_user":"$http_user_group" "$directory_path"

    setfacl --default -m g::rwX "$directory_path"
done
