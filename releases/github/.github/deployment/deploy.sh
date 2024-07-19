artifacts_path=$1
base_directory=$2
php_executable=$3

# Replace the tilde with the path to the home directory.
if [[ "$base_directory" =~ ^~ ]]; then
    base_directory="$HOME${base_directory:1}"
fi

releases_directory="$base_directory/releases"
current_directory_path="$base_directory/current"
lock_directory_path="$base_directory/deployment-currently-running"

# If this project was previously deployed with Deployer then the storage directory and .env file are
# in the "shared" directory.
if [[ -d "$base_directory/shared/storage" ]] && [[ -f "$base_directory/shared/.env" ]]; then
    real_storage_directory_path="$base_directory/shared/storage"
    real_env_file_path="$base_directory/shared/.env"
else
    real_storage_directory_path="$base_directory/storage"
    real_env_file_path="$base_directory/.env"
fi

is_first_deployment=$([[ -h "$current_directory_path" ]] && echo false || echo true)
has_created_lock_directory=false
release_directory_created=false
release_activated=false
use_datetime_release_directory_name=false

# By default we use an incrementing id for release directory names. Laravel Envoyer uses datetime names
# instead. If we detect that Envoyer was previously used to deploy this project then we will also use
# datetime names to keep things consistent.
if [[ -h "$current_directory_path" ]] && [[ "$(realpath "$current_directory_path")" =~ /20[0-9]{12}$ ]]; then
    use_datetime_release_directory_name=true
fi

run_hook () {
    hook_file_name=$1
    hook_parameters=("${@:2}")
    hook_entry_directory=$(pwd)

    # Run the hook, and pass down every argument except the first one (the first one is the name of the hook).
    tar -xf "$artifacts_path" ".github/deployment/hooks/$hook_file_name" -O | bash -se -- "$php_executable" "${hook_parameters[@]}"

    # Make sure the hook didn't change the directory.
    cd "$hook_entry_directory" || exit 1
}

on_exit() {
    script_status_code=$?

    if [[ -f "$artifacts_path" ]]; then
        echo "Deleting downloaded artifacts."

        rm "$artifacts_path"
    fi

    if [[ "$release_directory_created" == true && "$release_activated" == false ]]; then
        echo "Deleting new but unactivated release directory \"$new_release_directory\"."

        rm -rf "$new_release_directory"
    fi

    if [[ "$release_activated" == true ]] && [[ "$script_status_code" -ne 0 ]]; then
        echo "::warning::The new release has been activated!"
    fi

    if [[ "$has_created_lock_directory" == true ]]; then
        rmdir "$lock_directory_path"
    fi

    # Exit this trap with the original status code.
    exit "$script_status_code"
}
# This "trap" command will call the "on_exit" function when we exit this script.
trap on_exit INT EXIT TERM

mkdir -p "$releases_directory"

# Here we check if the "$releases_directory" is set correctly. Later on in the script we delete old
# release directories. We don't want to risk deleting something important.
#
# Most deployment scripts including this one use numeric names for release directories. If any directories
# inside "$releases_directory" does not have a numeric name then we are probably in the wrong place.
for release_directory_path in "$releases_directory/"*/ ; do
    if [[ -e "$release_directory_path" ]] && ! [[ $release_directory_path =~ /[0-9]+/$ ]] ; then
       echo -e "::error::The name of existing release directory \"$release_directory_path\" is not fully numeric, this should never happen."

       exit 1
    fi
done

if [[ -d "$lock_directory_path" ]]; then
    echo -e "::error::The directory \"$lock_directory_path\" exists, this means another deployment is currently running."

    exit 1
fi

if [[ ! -x "$(command -v "$php_executable")" ]]; then
    echo -e "::error::The PHP executable is set to \"$php_executable\", but that file either does not exist or is not executable."

    exit 1
elif [[ "$php_executable" != "php" ]]; then
    echo "Using \"$php_executable\" to run PHP."
fi

# Create a lock file to ensure we can't run multiple deployments at the same time. (https://mywiki.wooledge.org/BashFAQ/045)
mkdir "$lock_directory_path"

has_created_lock_directory=true

if [[ "$use_datetime_release_directory_name" == true ]]; then
    new_release_directory="$releases_directory/$(date +"%Y%m%d%H%M%S")"
else
    current_release_id=$(ls "$releases_directory" | sort --numeric-sort | tail -n1) || 0;

    new_release_directory="$releases_directory/$((current_release_id + 1))"
fi

echo "Creating directory \"$new_release_directory\" for the new release."

mkdir "$new_release_directory"

release_directory_created=true

echo "Creating a symlink to the storage directory."

if [[ ! -d "$real_storage_directory_path" ]]; then
    mkdir -p "$real_storage_directory_path/"{app/public,framework/{cache/data,sessions,testing,views},logs};
fi

ln -nsfr "$real_storage_directory_path" "$new_release_directory/storage"

if [[ ! -s "$real_env_file_path" ]]; then
    touch "$real_env_file_path"

    echo -e "::error::Your \"$real_env_file_path\" file is empty. Run the deployment again after you've filled it in."

    exit 1
fi

echo "Creating a symlink to the .env file."

ln -nsfr "$real_env_file_path" "$new_release_directory/.env"

echo "Extracting deployment artifacts."

cd "$new_release_directory" || exit 1

tar --extract --file="$artifacts_path"

if ! [[ $("$php_executable" artisan tinker --help) =~ "--execute" ]]; then
    echo -e "::error::Laravel Tinker is not installed or you are using an outdated version. Laravel Tinker version ^2.0 is required."

    exit 1
fi

run_hook "set-file-permissions.sh" "$new_release_directory"

run_hook "before-activation.sh" "$base_directory" "$artifacts_path"

if [[ -h "$current_directory_path" ]]; then
    previous_release_directory_path=$(realpath "$current_directory_path")
fi

echo "Activating the new release."

# We symlink our new release to the "current" directory. This activates the new release.
ln -nsfr "$new_release_directory" "$current_directory_path"

release_activated=true

if [[ "$is_first_deployment" == false ]]; then
    run_hook "flush-opcache.sh" "$current_directory_path" "$previous_release_directory_path"
fi

run_hook "after-activation.sh" "$base_directory" "$artifacts_path"

# Keep only the 3 newest release directories.
for old_release_directory in $(ls "$releases_directory" | sort --numeric-sort --reverse | tail -n+4) ; do
    echo "Deleting old release directory \"$releases_directory/$old_release_directory\"."

    rm -rf "${releases_directory:?}/$old_release_directory"
done
