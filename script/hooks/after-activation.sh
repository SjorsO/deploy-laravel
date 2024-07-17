php_executable=$1
base_directory=$2
artifacts_path=$3

"$php_executable" artisan schedule:interrupt

"$php_executable" artisan queue:restart

if [[ $("$php_executable" artisan list) =~ "horizon:terminate" ]]; then
    "$php_executable" artisan horizon:terminate
fi
