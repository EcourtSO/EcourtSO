#!/bin/sh

_debug() {
	if [ -n "${DEBUG}" ]
	then
		echo "DEBUG:   $1" >&2 
		shift
		for text in "$@"
		do
			echo "         ${text}" >&2
		done
	fi
}

_error() {
	echo "ERROR:   $1" >&2
	shift
	for text in "$@"
	do
		echo "         ${text}" >&2
	done
}

findjava() {
	if [ -n "${JAVA_HOME}" ] && [ -x "${JAVA_HOME}/bin/java" ]
	then
		JAVACMD="${JAVA_HOME}/bin/java"
		_debug "Using \$JAVA_HOME to find java virtual machine."
	else
		JAVACMD=$(which java)
		if [ -n "${JAVACMD}" ] && [ -x "${JAVACMD}" ]
		then
			_debug "Using \$PATH to find java virtual machine."
		elif [ -x /usr/bin/java ]
		then
			_debug "Using /usr/bin/java to find java virtual machine."
			JAVACMD=/usr/bin/java
		fi
	fi

	# if we were successful, we return 0 else we complain and return 1
	if [ -n "${JAVACMD}" ] && [ -x "${JAVACMD}" ]
	then
		_debug "Using '$JAVACMD' as java virtual machine..."
		if [ -n "${DEBUG}" ]
		then
			"$JAVACMD" -version
		fi
		return 0
	else
		_error "Couldn't find a java virtual machine," \
		       "define JAVA_HOME or PATH."
		return 1
	fi
}

_debug "DigiSigner parameters are '${@}'."
_debug "$(uname -a)"

# find JRE
findjava
if [ $? -ne 0 ]
then
	exit 1
fi

# we try to find DigiSigner.jar
digipath=$(dirname "$0")
if [ ! -f "${digipath}/DigiSigner.jar" ]
then
	_error "Couldn't find DigiSigner under '${digipath}'."
	exit 1
else	
	_debug "DigiSigner directory is '${digipath}'."
	break
fi

# run DigiSigner
_debug "Calling: '${JAVACMD} -jar ${digipath}/DigiSigner.jar $@'."
"${JAVACMD}" -jar ${digipath}/DigiSigner.jar "$@"
