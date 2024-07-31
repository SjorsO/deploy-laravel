php_executable=$1
base_directory=$2
artifacts_path=$3

# Available since Laravel 10
if [[ $("$php_executable" artisan list) =~ "schedule:interrupt" ]]; then
    "$php_executable" artisan schedule:interrupt
fi

"$php_executable" artisan queue:restart

if [[ $("$php_executable" artisan list) =~ "horizon:terminate" ]]; then
    "$php_executable" artisan horizon:terminate
fi

if [[ $("$php_executable" artisan list) =~ "pulse:restart" ]]; then
    "$php_executable" artisan pulse:restart
fi
