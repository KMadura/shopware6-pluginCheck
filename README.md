# shopware6-plugincheck

This is a simple script written to check for any easy problems, errors and sytax errors within our plugins. This script should not be used for general plugin testing as there are various mature tools to do that, including tools provided by shopware itself within psh.phar file.

This script lists:
 - empty directories
 - empty files
 - existing symlinks
 - php syntax errors
 - json syntax errors
 - xml syntax errors
 - files over 100KB
 - current PHP version
 - current PHP locale
 - database connection

This script doesn't modify any files. Can be executed within docker container or on a host machine.

## Usage

File should be placed in shopware's base directory where .env file and custom directory exists. Script will check if it is placed in right place anyway.

To run checks simply execute pcheck.sh script. If you pass plugin's name as argument then the script will check only this particular plugin unless it can't find plugin's directory.
