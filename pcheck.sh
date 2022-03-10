#!/bin/bash
# Author: Krzysztof Madura - 2022

pGlobalTestsTitle="Host"
pDockerOnly=0
if [[ -f "/.dockerenv" ]]
then
	echo "You are running this script from within a docker container, some functionalities may not work"
	pGlobalTestsTitle="Docker"
	pDockerOnly=1
else
	echo "You are running this script from host, database connection may not work"
fi

#
# Plugin selection
#

pPluginDirectory="custom/plugins"
pPluginName=$1

if [[ ! -d $pPluginDirectory ]]
then
	echo "Error! Could not find custom/plugins directory. Are you sure this script is placed in correct location?"
	exit
fi

if [[ ! -z $pPluginName ]]
then
	if [[ ! -d "$pPluginDirectory/$pPluginName" ]]
	then
		echo "Warning! Could not find plugin with a name \"$pPluginName\", all plugins will be checked"
		pPluginName=""
	else
		pPluginDirectory="$pPluginDirectory/$pPluginName"
	fi
fi

#
# Checking for dependencies
#

pDependencyJsonLint=1
if [[ $(command -v jsonlint-php | wc -c) -eq 0 ]]
then
	pDependencyJsonLint=0
	echo "Warning! Missing command <jsonlint-php>, please install package <jsonlint>"
fi

pDependencyXmlLint=1
if [[ $(command -v xmllint | wc -c) -eq 0 ]]
then
	pDependencyXmlLint=0
	echo "Warning! Missing command <xmllint>, please install package <libxml2-utils>"
fi

pDependencyPhp=1
if [[ $(command -v php | wc -c) -eq 0 ]]
then
	pDependencyPhp=0
	echo "Warning! Missing command <php>, please install package <php*-cli>"
fi

pDependencyMysql=1
if [[ $(command -v mysql | wc -c) -eq 0 ]]
then
	pDependencyMysql=0
	echo "Warning! Missing command <mysql>, please install package <mysql-client>"
fi

echo -e "Checking plugins\n"

#
# Testing functions
#

pCheckEmptyDir () {
	for ed in $(find . -empty -type d)
	do
		echo "[$1] empty directory: "$(echo -n $ed | sed -e 's/^\.//')
	done
}

pCheckEmptyFile () {
	for ef in $(find . -empty -type f)
	do
		echo "[$1] empty file: "$(echo -n $ef | sed -e 's/^\.//')
	done
}

pCheckSymlinks () {
	for ds in $(find . -type l)
	do
		echo "[$1] symlink: "$(echo -n $ds | sed -e 's/^\.//')
	done
}

pCheckDetectPhpErrors () {
	if [[ $pDependencyPhp -eq 0 ]]
	then
		exit
	fi

	for pef in $(find . -type f -name "*.php")
	do
		foundsyntaxerrors=$(php -l $pef | grep -v 'No syntax errors')
		if [[ $(echo -n "$foundsyntaxerrors" | wc -l) -gt 0 ]]
		then
			echo "[$1] php syntax errors: "$(echo -n $pef | sed -e 's/^\.//')
			echo $foundsyntaxerrors
		fi
	done
}

pCheckDetectJsonErrors () {
	if [[ $pDependencyJsonLint -eq 0 ]]
	then
		exit
	fi

	for joef in $(find . -type f -name "*.json")
	do
		foundsyntaxerrors=$(jsonlint-php $joef)
		# First line with "Valid" word is ignored
		if [[ $(echo -n $foundsyntaxerrors | wc -l) -gt 1 ]]
		then
			echo "[$1] json syntax errors: "$(echo -n $joef | sed -e 's/^\.//')
			echo $foundsyntaxerrors
		fi
	done
}

pCheckDetectXmlErrors () {
	if [[ $pDependencyXmlLint -eq 0 ]]
	then
		exit
	fi

	for xmlf in $(find . -type f -name "*.xml")
	do
		foundsyntaxerrors=$(xmllint --noout --debug "$xmlf" 2>&1);
		if [[ $? -gt 0 ]]
		then
			echo "[$1] xml syntax errors: "$(echo -n $xmlf | sed -e 's/^\.//')
			echo $foundsyntaxerrors
		fi
	done
}

pCheckFindLargeFiles () {
	for file in $(find . -type f)
	do
		if [[ $(du "$file" | awk '{print $1}') -gt 100 ]]
		then
			echo "[$1] large file: "$(du -h "$file" | sed -e 's/\s\.\// \//')
		fi
	done
}

#
# Global tests
#

pGetPhpVersion () {
	if [[ $pDependencyPhp -eq 0 ]]
	then
		exit
	fi
	
	echo "[$pGlobalTestsTitle] PHP version: "$(php -v | head -1)
}

pGetPhpLocale () {
	if [[ $pDependencyPhp -eq 0 ]]
	then
		exit
	fi
	
	echo "[$pGlobalTestsTitle] PHP locale: "$(php -r 'echo locale_get_default();')
}

pGetMysqlConn () {
	if [[ $pDependencyMysql -eq 0 ]]
	then
		exit
	fi
	
	if [[ ! -f ".env" ]]
	then
		echo "[$pGlobalTestsTitle] MySQL connection: cannot find .env file!"
		exit
	fi
	
	if [[ $pDependencyPhp -eq 0 ]]
	then
		exit
	fi
	
	# 0 - user, 1 - pass, 2 - host, 3 - port, 4 - name
	pDatabase=($(cat .env | grep 'DATABASE_URL' | grep -o -P '(?<=mysql:\/\/).+' | sed -e 's/[:@\/]/ /g'))
	
	mysql --user="${pDatabase[0]}" --password="${pDatabase[1]}" --host="${pDatabase[2]}" --port="${pDatabase[3]}" "${pDatabase[4]}" -e '\q' 2>/dev/null
	if [[ $? -gt 0 ]]
	then
		if [[ $pDockerOnly -eq 1 ]]
		then
			echo "[$pGlobalTestsTitle] MySQL connection: FAIL, check your .env file"
		else
			echo "[$pGlobalTestsTitle] MySQL connection: FAIL, probably OK inside your docker container"
		fi
	else
		echo "[$pGlobalTestsTitle] MySQL connection: OK"
	fi
}

#
# Running tests
#

pRunAllTests () {
	pCheckEmptyDir $1
	pCheckEmptyFile $1
	pCheckSymlinks $1
	pCheckDetectPhpErrors $1
	pCheckDetectJsonErrors $1
	pCheckDetectXmlErrors $1
	pCheckFindLargeFiles $1
}

pRunGlobalTests () {
	pGetPhpVersion
	pGetPhpLocale
	pGetMysqlConn
}

#
# Main loop
#

(
	cd $pPluginDirectory

	if [[ -z $pPluginName ]]
	then
		for pDirectory in *
		do
			(
				cd $pDirectory
				pRunAllTests $pDirectory
			)
		done
	else
		pRunAllTests $pPluginName
	fi
)

pRunGlobalTests

echo -e "\nFinished listing problems and global parameters"
