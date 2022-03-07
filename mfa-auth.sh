#!/bin/sh

# Copyrights Wojtek Kubiak
# Version 1.2 (dev and main continue to grow as well)
# Default filename values - change this or add as environment values, depending on your own needs
MFA_SERIAL_FILE=".mfaserial"
AWS_TOKEN_FILE=".awstoken"
TMP_DIR="${HOME}/.aws/CFG"
CREDENTIALS_FILE="${HOME}/.aws/credentials"
MFA_PROFILE="mfa"
DURATION="7200" #how long the token will work in seconds
DEFAULT_PROFILE="default"
if [ "$1" != "" ]; then
	DEFAULT_PROFILE=$1
	MFA_SERIAL_FILE=".mfaserial_$1"
	AWS_TOKEN_FILE=".awstoken_$1"
	MFA_PROFILE="mfa_$1"
fi 

#echo "[DEBUG] DEFAULT_PROFILE = $DEFAULT_PROFILE"
#echo "[DEBUG] MFA_SERIAL_FILE = $MFA_SERIAL_FILE"
#echo "[DEBUG] AWS_TOKEN_FILE = $AWS_TOKEN_FILE"
#echo "[DEBUG] MFA_PROFILE = $MFA_PROFILE"

# Validate that the configuration has been done before
# If not, prompt the user to run that first
if [ ! -e $CREDENTIALS_FILE ]; then
	echo "Please run first time configuration using aws configure"
else

	# Validate that the MFA has been done before
	# If not, prompt the user to run that first
	if [ ! -e $TMP_DIR/$MFA_SERIAL_FILE ]; then
		echo "Configuration is missing"
		mkdir -p ${TMP_DIR} 
		# A loop to continue prompting the user for the device serial code until a non-empty string is returned
		while true; do
				read -p "Please input the ARN (e.g. \"arn:aws:iam::12345678:mfa/username\"): " mfa
				case $mfa in
					"") echo "Please input a valid value.";;
					* ) echo $mfa > $TMP_DIR/$MFA_SERIAL_FILE; break;;
				esac
		done
	fi

	# Retrieve the serial code from file
	_MFA_SERIAL=`cat $TMP_DIR/$MFA_SERIAL_FILE`

	# Function for prompting for MFA token code
	promptForMFA(){
	while true; do
		echo "Trying authenticate for ${_MFA_SERIAL}"	
		read -p "Please input your 6 digit MFA token: " token
		case $token in
			[0-9][0-9][0-9][0-9][0-9][0-9] ) _MFA_TOKEN=$token; break;;
			* ) echo "Please enter a valid 6 digit pin." ;;
		esac
		_MFA_TOKEN=$token
	done
	# Run the awscli command and save results in var
	_authenticationOutput=`aws sts get-session-token --duration-seconds ${DURATION} --serial-number ${_MFA_SERIAL} --token-code ${_MFA_TOKEN} --profile ${DEFAULT_PROFILE}`  
#echo "[DEBUG] #### COMMAND ####"
#echo "[DEBUG] aws sts get-session-token --duration-seconds ${DURATION} --serial-number ${_MFA_SERIAL} --token-code ${_MFA_TOKEN} --profile ${DEFAULT_PROFILE}"
	# Save authentication to some file when token was generated
	if [ ${#_authenticationOutput} -gt 10 ]; then
		echo $_authenticationOutput > $TMP_DIR/$AWS_TOKEN_FILE;
#echo "[DEBUG] authenticationOutput: $_authenticationOutput"
#echo "[DEBUG] Token file '$TMP_DIR/$AWS_TOKEN_FILE' updated succesfully !!!"
	fi
	}

	calculate_seconds_left() {
		_authExpiration=`echo $_authenticationOutput | jq -r '.Credentials.Expiration'`
		_nowTime=`date -u +'%Y-%m-%dT%H:%M:%S+00:00'`
	
		# Retrieving is not sufficient, since we are not sure if this token has expired
		t1=$(date -j -f "%Y-%m-%dT%H:%M:%S+00:00" "$_authExpiration" "+%s")
		t2=$(date -j -f "%Y-%m-%dT%H:%M:%S+00:00" "$_nowTime" "+%s")
		seconds_left=$((${t1} - ${t2}))
	#seconds_left=1000

	}

	updateCredentialsFile() {
		# "Return" the values to the calling script.
		# There are a few ways to "return", for example writing to file
		# Here, we assume that this script is "sourced" - see more on "sourcing" here: https://bash.cyberciti.biz/guide/Source_command
		_AWS_ACCESS_KEY_ID=`echo ${_authenticationOutput} | jq -r '.Credentials.AccessKeyId'`
		_AWS_SECRET_ACCESS_KEY=`echo ${_authenticationOutput} | jq -r '.Credentials.SecretAccessKey'`
		_AWS_SESSION_TOKEN=`echo ${_authenticationOutput} | jq -r '.Credentials.SessionToken'`
		_AWS_EXPIRATION=`echo ${_authenticationOutput} | jq -r '.Credentials.Expiration'`

#echo "[DEBUG] _AWS_ACCESS_KEY_ID=$_AWS_ACCESS_KEY_ID"
#echo "[DEBUG] _AWS_SECRET_ACCESS_KEY=$_AWS_SECRET_ACCESS_KEY"
#echo "[DEBUG] _AWS_SESSION_TOKEN=$_AWS_SESSION_TOKEN"
#echo "[DEBUG] _AWS_EXPIRATION=$_AWS_EXPIRATION"

		# Checking if $MFA_PROFILE exists in credential file
		isInFile=$(cat ${HOME}/.aws/credentials | grep -c "$MFA_PROFILE")

		if [ $isInFile -eq 0 ]; then
		# Nie znalazlem MFA_PROFILE w pliku wiec dopisuje
		echo "" >> ${HOME}/.aws/credentials
		echo "[$MFA_PROFILE]" >> ${HOME}/.aws/credentials
		fi

		# Writing new vaules to credentials file
		TMP_CRED_FILE="${HOME}/.aws/credentials_tmp"
		skip=0
		# File creation
		#echo "#By Woku" > $TMP_CRED_FILE

		while IFS= read -r line
		do
			if [[ $skip == 0 ]]; then
				echo "$line" >> $TMP_CRED_FILE
			else
				# waiting for blank line to continue coping from orginal credentials to tmp
				if [[ -z $line ]]; then
					echo "$line" >> $TMP_CRED_FILE
					skip=0
				fi	
			fi
			if [[ $line == "[$MFA_PROFILE]" ]]; then
				echo "aws_access_key_id =" $_AWS_ACCESS_KEY_ID >> $TMP_CRED_FILE
				echo "aws_secret_access_key =" $_AWS_SECRET_ACCESS_KEY >> $TMP_CRED_FILE
				echo "aws_session_token =" $_AWS_SESSION_TOKEN >> $TMP_CRED_FILE
				echo "aws_expiration =" $_AWS_EXPIRATION >> $TMP_CRED_FILE
#echo "[DEBUG] MFA_PROFILE = $MFA_PROFILE updated in 'credentials' file succesfully !!!"
				# Skip next rows until blank line appears
				skip=1
			fi
		done < "${HOME}/.aws/credentials"

		mv ${HOME}/.aws/credentials ${TMP_DIR}/.credentials_old
		mv $TMP_CRED_FILE ${HOME}/.aws/credentials
		calculate_seconds_left
		minutes_left=$(( $seconds_left / 60 ))
		echo "Credential file was updated succesfully. New token valid for $minutes_left minutes."
	}

	##############################
	###### MAIN STARTS HERE ######

	# If token is present, retrieve it from file
	# Else invoke the prompt for mfa function
	if [ -e $TMP_DIR/$AWS_TOKEN_FILE ]; then
#echo "[DEBUG] Token exists in location $TMP_DIR/$AWS_TOKEN_FILE. Retreving the TOKEN"
		_authenticationOutput=`cat $TMP_DIR/$AWS_TOKEN_FILE`
		calculate_seconds_left
		# Check for the expiration value against the current time
		# If expired, invoke the prompt for mfa function
		if [[ $seconds_left -lt 0 ]]; then
			echo "Your last token has expired"
			promptForMFA
			updateCredentialsFile
		else
			# Nothing to do - token is VALID
			echo "Token valid for next seconds: " $seconds_left
		fi
	else
	echo "[DEBUG] NO TOKEN FILE in location $TMP_DIR/$AWS_TOKEN_FILE"
		promptForMFA
		updateCredentialsFile
	fi
fi

