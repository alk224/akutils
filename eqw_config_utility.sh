#!/bin/bash

## Utility to configure the config file required for my qiime workflow to function nicely

## Needs help info and usage still...

## Set working directory
	workdir=(`pwd`)

## Check for config file (in subdirectory called "eqw_resources stored in directory where script is located )

scriptdir="$( cd "$( dirname "$0" )" && pwd )"
globalconfigsearch=(`ls $scriptdir/eqw_resources/eqw*.config 2>/dev/null`)
localconfigsearch=(`ls eqw*.config 2>/dev/null`)
DATE=`date +%Y%m%d-%I%M%p`

echo "
This will help you configure your eqw config file for running eqw
workflows.

First, would you like to configure your global settings or make
a custom config file to override your global settings?  A custom
config file will reside within your current directory.

Enter \"global\" or \"local\".
"
read globallocal

		if [[ ! $globallocal == "global" && ! $globallocal == "local" ]]; then
		echo "		Invalid entry.  global or local only."
		read yesno
		if [[ ! $globallocal == "global" && ! $globallocal == "local" ]]; then
		echo "		Invalid entry.  Exiting.
		"
		exit 1
		fi
		fi

if [[ $globallocal == global ]]; then
	echo "
		OK.  Checking for existing global config file in eqw
		resources directory.
		($scriptdir/eqw_resources/)
	"
	sleep 1


if [[ ! -f $globalconfigsearch ]]; then
	echo "		No config file detected in eqw resources
		directory.
		($scriptdir/eqw_resources/)
		Shall I create a new one for you (yes or no)?"

		if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
		echo "		Invalid entry.  Yes or no only."
		read yesno
		if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
		echo "		Invalid entry.  Exiting.
		"
		exit 1
		fi
		fi

		if [[ $yesno == "yes" ]]; then
		echo "		OK.  Creating global eqw config file.
		($scriptdir/eqw_resources/eqw.global.config)
		"
		cat $scriptdir/eqw_resources/blank_config.config > $scriptdir/eqw_resources/eqw.global.config
		configfile=($scriptdir/eqw_resources/eqw.global.config)
		fi

		if [[ $yesno == "no" ]]; then
		echo "		OK.  Please enter the path of the
		config file you want to update.
		"
		read -e configfile
		fi

	else
	echo "		Found config file."
	echo "		$globalconfigsearch
	"
	sleep 1
	configfile=($globalconfigsearch)
fi
fi

if [[ $globallocal == local ]]; then
	echo "
		OK.  Checking for existing config file in current
		directory.
		($workdir/)
	"
	sleep 1

if [[ ! -f $localconfigsearch ]]; then
	echo "		No config file detected in local directory.
		Shall I create one for you (yes or no)?"
		read yesno
	
		if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
			echo "		Invalid entry.  Yes or no only."
			read yesno
			if [[ ! $yesno == "yes" && ! $yesno == "no" ]]; then
				echo "		Invalid entry.  Exiting.
				"
				exit 1
			fi
		fi

		if [[ $yesno == "yes" ]]; then

			if [[ -e $scriptdir/eqw_resources/eqw.global.config ]]; then
			echo "		Found global config file.
		($scriptdir/eqw_resources/eqw.global.config)
		Do you want to generate a whole new config file or make a
		copy of the existing global file and modify that (new or
		copy)?"
			read newcopy

				if [[ ! $newcopy == "new" && ! $newcopy == "copy" ]]; then
					echo "		Invalid entry.  new or copy only."
					read yesno
					if [[ ! $newcopy == "new" && ! $newcopy == "copy" ]]; then
						echo "		Invalid entry.  Exiting.
						"
						exit 1
					fi
				fi
			fi

		if [[ $newcopy == "new" ]]; then
			echo "		OK.  Creating new workflow file in your
		current directory.
		($workdir/eqw.$DATE.config)
		"
			cat $scriptdir/eqw_resources/blank_config.config > $workdir/eqw.$DATE.config
			configfile=($workdir/eqw.$DATE.config)
		fi

		if [[ $newcopy == "copy" ]]; then
			echo "		OK.  Copying global config file for local
		use in your current directory.
		($workdir/eqw.$DATE.config)
		"
			cat $scriptdir/eqw_resources/eqw.global.config > $workdir/eqw.$DATE.config
			configfile=($workdir/eqw.$DATE.config)
		fi


		if [[ $yesno == "no" ]]; then
			echo "		OK.  Please enter the path of the
		config file you want to update.
		"
			read -e configfile
		fi
	else
	echo "		Found config file."
	echo "		$localconfigsearch
	"
	sleep 1
	configfile=($localconfigsearch)
	fi
fi
fi


	echo "		File selected is:
		$configfile
		Reading configurable fields...
	"
	sleep 1
	cat $configfile | grep -v "#" | grep -E -v '^$'

	echo "
		I will now go through each configurable field and require
		your input.  Press enter to retain the current value or 
		enter a new value.  When entering paths (say to gg database)
		remember to use tab-autocomplete to avoid errors.
	"



for field in `grep -v "#" $configfile | cut -f 1`; do
	fielddesc=`grep $field $configfile | grep "#" | cut -f 2-3`

	echo "		Field: $fielddesc"
	setting=`grep $field $configfile | grep -v "#" | cut -f 2`
	echo "		Current setting is: $setting
		Enter new value (or press enter to keep current setting):
	"
	read -e newsetting
	if [[ ! -z "$newsetting" ]]; then
	sed -i -e "s@^$field\t$setting@$field\t$newsetting@" $configfile
	echo "		Setting changed.
	"
	else
	echo "		Setting unchanged.
	"
	fi
done

echo "		$configfile updated.
"

