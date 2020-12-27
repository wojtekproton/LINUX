#!/bin/bash

# Default filename values - change this or add as environment values, depending on your own needs
MFA_SERIAL_FILE=".mfaserial"
AWS_TOKEN_FILE=".awstoken"
TMP_DIR="${HOME}/.aws/TMP"
MFA_PROFILE="mfa"
DURATION="900" #how long the token will work in seconds
DEFAULT_PROFILE="default"
if [ "$1" != "" ]; then
	DEFAULT_PROFILE=$1
	MFA_SERIAL_FILE=".mfaserial_$1"
	AWS_TOKEN_FILE=".awstoken_$1"
fi 

# Validate that the configuration has been done before
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

# Retrieve the serial code 
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
  done

  # Run the awscli command
  _authenticationOutput=`aws sts get-session-token --duration-seconds ${DURATION} --serial-number ${_MFA_SERIAL} --token-code ${_MFA_TOKEN} --profile ${DEFAULT_PROFILE}`
  
  # Save authentication to some file
  echo "AWS cmd: " 
  echo "aws sts get-session-token --duration-seconds ${DURATION} --serial-number ${_MFA_SERIAL} --token-code ${_MFA_TOKEN} --profile ${DEFAULT_PROFILE}"
  echo $_authenticationOutput > $TMP_DIR/$AWS_TOKEN_FILE;
  `export AWS_PROFILE=${MFA_PROFILE}`
}

# If token is present, retrieve it from file
# Else invoke the prompt for mfa function
if [ -e $TMP_DIR/$AWS_TOKEN_FILE ]; then
  _authenticationOutput=`cat $TMP_DIR/$AWS_TOKEN_FILE`
  _authExpiration=`echo $_authenticationOutput | jq -r '.Credentials.Expiration'`
  _nowTime=`date -u +'%Y-%m-%dT%H:%M:%SZ'`
  
  # Retrieving is not sufficient, since we are not sure if this token has expired
export AWS_SESSION_TOKEN=$_AWS_SESSION_TOKEN
  # Check for the expiration value against the current time
  # If expired, invoke the prompt for mfa function
  if [ "$_authExpiration" \< "$_nowTime" ]; then
    echo "Your last token has expired"
    promptForMFA
  else
	echo "Token VALID"
  fi
else
  promptForMFA
fi

# "Return" the values to the calling script.
# There are a few ways to "return", for example writing to file
# Here, we assume that this script is "sourced" - see more on "sourcing" here: https://bash.cyberciti.biz/guide/Source_command
_AWS_ACCESS_KEY_ID=`echo ${_authenticationOutput} | jq -r '.Credentials.AccessKeyId'`
_AWS_SECRET_ACCESS_KEY=`echo ${_authenticationOutput} | jq -r '.Credentials.SecretAccessKey'`
_AWS_SESSION_TOKEN=`echo ${_authenticationOutput} | jq -r '.Credentials.SessionToken'`
_AWS_EXPIRATION=`echo ${_authenticationOutput} | jq -r '.Credentials.Expiration'`



# Writing new vaules to credentials file
TMP_CRED_FILE="${HOME}/.aws/credentials_tmp"
skip=0
#echo "# By Woku " > $TMP_CRED_FILE

while IFS= read -r line
do
	if [[ $skip == 0 ]]; then
		echo "$line" >> $TMP_CRED_FILE
	else
		# waiting for blank line to continue coping from old credentials to tmp
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
		
		# Skip next rows until blank line appears
		skip=1
	fi
	
done < "${HOME}/.aws/credentials"

mv ${HOME}/.aws/credentials ${HOME}/.aws/TMP/.credentials_old
mv $TMP_CRED_FILE ${HOME}/.aws/credentials
