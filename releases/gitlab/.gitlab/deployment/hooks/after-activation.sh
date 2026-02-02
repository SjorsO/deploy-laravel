php_executable=$1
base_directory=$2
artifacts_path=$3

available_commands=$("$php_executable" artisan list)

# Available since Laravel 10
if [[ "$available_commands" =~ "schedule:interrupt" ]]; then
    "$php_executable" artisan schedule:interrupt
fi

"$php_executable" artisan queue:restart

if [[ "$available_commands" =~ "horizon:terminate" ]]; then
    "$php_executable" artisan horizon:terminate
fi

if [[ "$available_commands" =~ "pulse:restart" ]]; then
    "$php_executable" artisan pulse:restart
fi
