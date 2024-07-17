php_executable=$1
base_directory=$2
artifacts_path=$3

"$php_executable" artisan storage:link

"$php_executable" artisan config:cache

"$php_executable" artisan route:cache

"$php_executable" artisan view:cache

"$php_executable" artisan migrate --force
