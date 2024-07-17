# We flush OPCache by calling the "opcache_reset()" php function. We do this by using Curl to send a
# web request to the server. We can't call this function on the command line, this would flush the
# cli cache, not the web cache. Calling "opcache_reset()" is the most efficient way to flush OPCache.

php_executable=$1
current_release_directory_path=$2
previous_release_directory_path=$3

has_flushed_opcache=false

opcache_reset_script_file_name="$(head -c 512 /dev/urandom | tr -dc 0-9a-f | head -c 8).php"

# We flush OPCache right after we create the symlink for our new release. Nginx needs a brief moment
# to realise that the release directory has been changed. That's why we have to create our file twice.
opcache_reset_script_file_path_1="$current_release_directory_path/public/$opcache_reset_script_file_name"
opcache_reset_script_file_path_2="$previous_release_directory_path/public/$opcache_reset_script_file_name"

on_exit() {
    script_status_code=$?

    if [[ -f "$opcache_reset_script_file_path_1" ]]; then
        rm "$opcache_reset_script_file_path_1"
    fi

    if [[ -n "$previous_release_directory_path" ]] && [[ -f "$opcache_reset_script_file_path_2" ]]; then
        rm "$opcache_reset_script_file_path_2"
    fi

    if [[ "$has_flushed_opcache" == false ]]; then
        echo "{STYLE_ERROR}Failed to flush OPCache. The APP_URL in your .env file is set to \"$app_url\", is this correct?{STYLE_RESET}"
    fi

    # Exit this trap with the original status code.
    exit "$script_status_code"
}
# This "trap" command will call the "on_exit" function when we exit this script.
trap on_exit INT EXIT TERM

cat << PHP > "$opcache_reset_script_file_path_1"
<?php

echo function_exists('opcache_reset') && opcache_reset()
    ? "OPCache flushed successfully.\n"
    : "OPCache is not enabled.\n";
PHP

if [[ -n "$previous_release_directory_path" ]]; then
    cp "$opcache_reset_script_file_path_1" "$opcache_reset_script_file_path_2"
fi

app_url=$("$php_executable" artisan tinker --execute "echo rtrim(config('app.url'), '/')")

echo "Pinging \"$app_url\" to flush OPCache."

curl "$app_url/$opcache_reset_script_file_name" \
    --silent \
    --show-error \
    --fail \
    --retry 5 \
    --max-time 5 \
    --retry-max-time 60

has_flushed_opcache=true
