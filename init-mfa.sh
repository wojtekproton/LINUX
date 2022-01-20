#!/bin/sh

# Default filename values - change this or add as environment values, depending on your own needs
MFA_SERIAL_FILE=".mfaserial"
TMP_DIR="${HOME}/.aws/TMP"

# For variable value of $TMP_DIR, you can either set this as a path that is .gitignored in this project, for saving this developer's context for this project, or a absolute path from root as a system configuration.  wrap this script with some other environment variable injected for this value

mkdir -p ${TMP_DIR} 

# A loop to continue prompting the user for the device serial code until a non-empty string is returned
echo "Tip - You can get your ARN for MFA device here: https://console.aws.amazon.com/iam/home#/security_credentials"
while true; do
    read -p "Please input the ARN (e.g. \"arn:aws:iam::12345678:mfa/username\"): " mfa
    case $mfa in
        "") echo "Please input a valid value.";;
        * ) echo $mfa > $TMP_DIR/$MFA_SERIAL_FILE; break;;
    esac
done
