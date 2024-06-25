#!/bin/bash

# Function for generic error handling
handle_error() {
    local error_message="$1"
    echo "Error: $error_message"
    exit 1
}

# Function to upload APK to BrowserStack and extract app_url
upload_apk_and_get_url() {
    local username="$1"
    local access_key="$2"
    local project_path=$(pwd)
    local apk_path="$project_path/android/app/build/outputs/apk/residentapp/release/Inji_universal.apk"

    if [[ -f "$apk_path" ]]; then
        response=$(curl -u "$username:$access_key" \
            -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
            -F "file=@$apk_path")
        # Add sleep for 5 seconds to allow the response to be processed
        sleep 60
        app_url=$(echo "$response" | jq -r '.app_url')
        if [[ ! -z "$app_url" ]]; then
            echo "$app_url"
        else
            handle_error "Failed to extract app_url from the response"
        fi
    else
        handle_error "APK file not found at $apk_path"
    fi
}

# Function to upload IPA to BrowserStack and extract app_url
upload_ipa_and_get_url() {
    local username="$1"
    local access_key="$2"
    local project_path=$(pwd)
    local ipa_path="$project_path/ios/Inji.ipa"
    
    if [[ -f "$ipa_path" ]]; then
        response=$(curl -u "$username:$access_key" \
            -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
            -F "file=@$ipa_path")
        # Add sleep for 5 seconds to allow the response to be processed
        sleep 60

        app_url=$(echo "$response" | jq -r '.app_url')
        if [[ ! -z "$app_url" ]]; then
            echo "$app_url"
        else
            handle_error "Failed to extract app_url from the response"
        fi
    else
        handle_error "IPA file not found at $ipa_path"
    fi
}

# Function to execute Android tests
execute_android_tests() {
    local app_url="$1"
    local username="$2"
    local access_key="$3"
    local test_type="$4"

    cd injitest

    # Update androidConfig.yml with the app_url obtained from BrowserStack
    sed -i "s|app:.*|app: $app_url|" androidConfig.yml
    sed -i "s|userName:.*|userName: $username|" androidConfig.yml
    sed -i "s|accessKey:.*|accessKey: $access_key|" androidConfig.yml


    # Run UI tests using Maven with the updated androidConfig.yml file and TestNG XML file based on the test type
    mvn clean test -DtestngXmlFile="android${test_type}.xml" -Dbrowserstack.config="androidConfig.yml"
}

# Function to execute iOS tests
execute_ios_tests() {
    local app_url="$1"
    local username="$2"
    local access_key="$3"
    local test_type="$4"
    local config_file="./iosConfig.yml"

    # Check if the configuration file exists
    if [ ! -f "$config_file" ]; then
        echo "Configuration file $config_file not found!"
        exit 1
    fi

    # Update iosConfig.yml with the app_url, username, and access_key obtained from BrowserStack using awk
    awk -v app_url="$app_url" -v username="$username" -v access_key="$access_key" '
    BEGIN { updated = 0 }
    /^app:/ { $0 = "app: " app_url; updated++ }
    /^userName:/ { $0 = "userName: " username; updated++ }
    /^accessKey:/ { $0 = "accessKey: " access_key; updated++ }
    { print }
    END { if (updated < 3) exit 1 }
    ' "$config_file" > "${config_file}.tmp" || { echo "Failed to update configuration file"; exit 1; }

    mv "${config_file}.tmp" "$config_file"
    
    echo "Configuration file updated:"

    # Run UI tests using Maven with the updated iosConfig.yml file and TestNG XML file based on the test type
    mvn clean test -DtestngXmlFile="ios${test_type}.xml" -Dbrowserstack.config="$config_file"
}


# Assigning parameters to variables
username=$1
access_key=$2
test_type=$3
platform=$4

# Upload APK/IPA to BrowserStack and get app_url based on platform
if [ "$platform" = "Android" ]; then
    app_url=$(upload_apk_and_get_url "$username" "$access_key")
    execute_android_tests "$app_url" "$username" "$access_key" "$test_type"
elif [ "$platform" = "IOS" ]; then
    app_url=$(upload_ipa_and_get_url "$username" "$access_key")
    execute_ios_tests "$app_url" "$username" "$access_key" "$test_type"
else
    handle_error "Invalid platform. Please use 'Android', 'IOS'."
fi
