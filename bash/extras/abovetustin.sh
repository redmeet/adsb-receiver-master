#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2018 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## SET INSTALLATION VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up AboveTustin..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "AboveTustin Setup" --yesno "AboveTustin is an ADS-B Twitter Bot. Uses dump1090-mutability to track airplanes and then tweets whenever an airplane flies overhead.\n\n  https://github.com/kevinabrandon/AboveTustin\n\nContinue setting up AboveTustin?" 12 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
        echo -e "\e[92m  AboveTustin setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

echo -e "\e[95m  Setting up AboveTustin on this device...\e[97m"
echo -e ""

## ENABLE THE USE OF /ETC/RC.LOCAL IF THE FILE DOES NOT EXIST

if [ ! -f /etc/rc.local ]; then
    echo ""
    echo -e "\e[95m  Enabling the use of the /etc/rc.local file...\e[97m"
    echo ""

    # In Debian Stretch /etc/rc.local has been removed.
    # However at this time we can bring this file back into play.
    # As to if in future releases this will work remains to be seen...

    echo -e "\e[94m  Creating the file /etc/rc.local...\e[97m"
    sudo tee /etc/rc.local > /dev/null <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF

    echo -e "\e[94m  Making /etc/rc.local executable...\e[97m"
    sudo chmod +x /etc/rc.local
    echo -e "\e[94m  Enabling the use of /etc/rc.local...\e[97m"
    sudo systemctl start rc-local
fi

## CHECK IF A PHANTOMJS ALREADY EXISTS OR IF A PRECOMPILED BINARY IS AVAILABLE FOR THIS DEVICE

echo -e "\e[95m  Checking for PhantomJS...\e[97m"
echo -e ""
if [[ -f "/usr/bin/phantomjs" ]] && [[ "`phantomjs --version`" == "${PHANTOMJS_VERSION}" ]] ; then
    # A PhantomJS binary which is the proper version appears to exist on this device.
    echo -e "\e[94m  PhantomJS is present on this device and is the proper version...\e[97m"
    PHANTOMJS_EXISTS="true"
else
    echo -e "\e[91m  PhantomJS is not present on this device or is not the proper version...\e[97m"
    PHANTOMJS_EXISTS="false"

    # Use function to detect cpu architecture.
    if [[ -z "${CPU_ARCHITECTURE}" ]] ; then
        Check_CPU
        echo -e ""
    fi

    if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "x86_64" ]] || [[ "${CPU_ARCHITECTURE}" = "i686" ]] ; then
        # A precompiled binary should be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary appears to be available for the \"${CPU_ARCHITECTURE}\" CPU arcitecture...\e[97m"
        PHANTOMJS_BINARY_AVAILABLE="true"
    else
        # A precompiled binary does not appear to be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary does is not available for the \"${CPU_ARCHITECTURE}\" CPU's arcitecture...\e[97m"
        PHANTOMJS_BINARY_AVAILABLE="false"

        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Warn the user of the build time if there is no binary available for download.
            # The user should be allowed to cancel out of the setup process at this time.
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "PhantomJS Binary Not Available" --yesno "It appears there is not a precompiled PhantomJS binary available for your devices architecture.\n\nThis script is capable of downloading and compiling the PhantomJS source but THIS MAY TAKE AN EXTREMELY LONG TO TO COMPLETE. Expect the build process to range anywhere from a half our to literally hours.\n\nDo you wish to compile PhantomJS from source?" 13 78
            if [[ $? -eq 1 ]] ; then
                # Setup has been halted by the user.
                echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
                echo "  Setup has been halted at the request of the user."
                echo -e ""
                echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
                echo -e "\e[92m  AboveTustin setup halted.\e[39m"
                echo -e ""
                read -p "Press enter to continue..." CONTINUE
                exit 1
            fi
        else
            # If the user elected to not compile the PhantomJS binary if needed in the installation configuration file exit now.
            if [[ ! "${ABOVETUSTIN_COMPILE_IF_NEEDED}" = "true" ]] ; then
                echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
                echo "  A prebuilt PhantomJS binary is not available for this system."
                echo -e ""
                echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
                echo -e "\e[92m  AboveTustin setup halted.\e[39m"
                echo -e ""
                exit 1
            fi
        echo -e "\e[94m  Will attempt to build the PhantomJS binary from source...\e[97m"
        echo -e ""
        fi
    fi
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e ""
echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""

# The package ttf-mscorefonts-installer requires contrib be added to the Debian repositories contained in /etc/apt/sources.list.
# The contrib flag does not need to be added for Raspbian Jessie and Ubuntu only Debian so far.
if [[ `lsb_release -si` = "Debian" ]] ; then
    echo -e "\e[94m  Adding the contrib component to the repositories contained sources.list...\e[97m"
    sudo sed -i 's/main/main contrib/g' /etc/apt/sources.list 2>&1
    echo -e "\e[94m  Updating the repository package lists...\e[97m"
    echo ""
    sudo apt-get update 2>&1
    echo ""
fi

# Detect the OS distribution and version.
DISTRO_ID=`. /etc/os-release; echo ${ID/*, /}`
DISTRO_RELEASE=`. /etc/os-release; echo ${VERSION_ID/*, /}`

# Check that the required packages are installed.
CheckPackage ttf-mscorefonts-installer
CheckPackage python3-pip
CheckPackage libstdc++6
CheckPackage flex
CheckPackage bison
CheckPackage gperf
CheckPackage ruby
CheckPackage perl
CheckPackage libsqlite3-dev
CheckPackage libfontconfig1
CheckPackage libfontconfig1-dev
CheckPackage libicu-dev
CheckPackage libfreetype6
CheckPackage libssl-dev
CheckPackage libjpeg-dev
CheckPackage python
CheckPackage libx11-dev
CheckPackage libxext-dev
CheckPackage libc6
CheckPackage curl

# Depending on the version of Debian, Raspbian, or Ubuntu the correct libpng-dev package needs to be installed.
# This is currently kind of sloppy and rushed and should definatly be refactored later.
case $DISTRO_ID in
    debian|raspbian)
        if [[ $DISTRO_RELEASE -ge "9" ]]; then
            CheckPackage libpng-dev
        else
            CheckPackage libpng12-dev
        fi
        ;;
    ubuntu)
        if [[ $DISTRO_RELEASE -ge "16.04" ]]; then
            CheckPackage libpng-dev
        else
            CheckPackage libpng12-dev
        fi
        ;;
    *)
        CheckPackage libpng12-dev
        ;;
esac

if [[ "${PHANTOMJS_BINARY_AVAILABLE}" = "false" ]] ; then
    # These packages are only needed if the user decided to build PhantomJS.
    CheckPackage build-essential
    CheckPackage g++
else
    # Package needed if the prebuilt PhantomJS binary is to be downloaded.
    CheckPackage bzip2
fi

## CONFIRM SETTINGS

# GATHER TWITTER API INFORMATION FROM THE USER

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Twiter Keys and Tokens" --yesno "In order to send Tweets to Twitter using AboveTustin you will need to obtain the proper keys and tokens from Twitter. You will need to sign up for a Twitter developer account at https://apps.twitter.com and create an application there in order to obtain this information.\n\nMore information on obtaining Twitter keys and access tokens can be found in the projects wiki page.\n\n  https://github.com/jprochazka/adsb-receiver/wiki/Setting-Up-AboveTustin\n\nProceed with the AboveTustin setup?" 18 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
        echo -e "\e[92m  AboveTustin setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

# If any exist assign the current Twitter keys and access tokens to variables.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    TWITTER_ACCESS_TOKEN_TITLE="Twitter Access Token"
    while [[ -z "${TWITTER_ACCESS_TOKEN}" ]]; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep -c "^access_token =" ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini` -gt 0 ]]; then
                TWITTER_ACCESS_TOKEN=$(grep "^access_token =" "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" | awk '{print $3}')
            fi
        fi
        TWITTER_ACCESS_TOKEN=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_ACCESS_TOKEN_TITLE}" --nocancel --inputbox "\nEnter your Twitter Access Token." 8 78 "${TWITTER_ACCESS_TOKEN}" 3>&1 1>&2 2>&3)
        TWITTER_ACCESS_TOKEN_TITLE="Twitter Access Token (REQUIRED)"
    done
    #
    TWITTER_ACCESS_TOKEN_SECRET_TITLE="Twitter Access Token Secret"
    while [[ -z "${TWITTER_ACCESS_TOKEN_SECRET}" ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep -c "^access_token_secret =" ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini` -gt 0 ]] ; then
                TWITTER_ACCESS_TOKEN_SECRET=$(grep "^access_token_secret =" "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" | awk '{print $3}')
            fi
        fi
        TWITTER_ACCESS_TOKEN_SECRET=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_ACCESS_TOKEN_SECRET_TITLE}" --nocancel --inputbox "\nEnter your Twitter Access Token Secret." 8 78 "${TWITTER_ACCESS_TOKEN_SECRET}" 3>&1 1>&2 2>&3)
        TWITTER_ACCESS_TOKEN_SECRET_TITLE="Twitter Access Token Secret (REQUIRED)"
    done
    #
    TWITTER_CONSUMER_KEY_TITLE="Twitter Consumer Key"
    while [[ -z "${TWITTER_CONSUMER_KEY}" ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep -c "^consumer_key =" ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini` -gt 0 ]] ; then
                TWITTER_CONSUMER_KEY=$(grep "^consumer_key =" "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" | awk '{print $3}')
            fi
        fi
        TWITTER_CONSUMER_KEY=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_CONSUMER_KEY_TITLE}" --nocancel --inputbox "\nEnter your Twitter Consumer Key." 8 78 "${TWITTER_CONSUMER_KEY}" 3>&1 1>&2 2>&3)
        TWITTER_CONSUMER_KEY_TITLE="Twitter Consumer Key (REQUIRED)"
    done
    #
    TWITTER_CONSUMER_SECRET_TITLE="Twitter Consumer Secret"
    while [[ -z "${TWITTER_CONSUMER_SECRET}" ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep -c "^consumer_secret =" ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini` -gt 0 ]] ; then
                TWITTER_CONSUMER_SECRET=$(grep "^consumer_secret =" "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" | awk '{print $3}')
            fi
        fi
        TWITTER_CONSUMER_SECRET=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_CONSUMER_SECRET_TITLE}" --nocancel --inputbox "\nEnter your Twitter Consumer Secret." 8 78 "${TWITTER_CONSUMER_SECRET}" 3>&1 1>&2 2>&3)
        TWITTER_CONSUMER_SECRET_TITLE="Twitter Consumer Secret (REQUIRED)"
    done
fi

# Ask for the receivers latitude and longitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Explain to the user that the receiver's latitude and longitude is required.
    RECEIVER_LATLON_DIALOG=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for distance calculations, you will now be asked to supply these values for your receiver.\n\nIf you do not have this information you can obtain it using the web based \"Geocode by Address\" utility hosted on another of the lead developers websites:\n\n  https://www.swiftbyte.com/toolbox/geocode" 15 78 3>&1 1>&2 2>&3)

    # Ask the user to confirm the receivers latitude, this will be prepopulated by the latitude assigned dump1090-mutability.
    RECEIVER_LATITUDE_TITLE="Receiver Latitude"
    while [[ -z "${RECEIVER_LATITUDE}" ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep "^latitude = " ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini | awk '{print $3}' | wc -c` -gt 1 ]] ; then
                RECEIVER_LATITUDE=$(grep "^latitude =" "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" | awk '{print $3}')
                RECEIVER_LATITUDE_SOURCE=", the value below is configured in AboveTustin"
            fi
        elif [[ -f /etc/default/dump1090-mutability ]]; then
            RECEIVER_LATITUDE=$(GetConfig "LAT" "/etc/default/dump1090-mutability")
            RECEIVER_LATITUDE_SOURCE=", the value below is configured in Dump1090"
        fi
        RECEIVER_LATITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${RECEIVER_LATITUDE_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver's latitude${RECEIVER_LATITUDE_SOURCE}:\n" 10 78 -- "${RECEIVER_LATITUDE}" 3>&1 1>&2 2>&3)
        RECEIVER_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done

    # Ask the user to confirm the receivers longitude, this will be prepopulated by the longitude assigned dump1090-mutability.
    RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
    while [[ -z "${RECEIVER_LONGITUDE}" ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini ]]; then
            if [[ `grep "^longitude = " ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini | awk '{print $3}' | wc -c` -gt 1 ]] ; then
                RECEIVER_LONGITUDE=$(grep "^longitude =" ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini | awk '{print $3}')
                RECEIVER_LONGITUDE_SOURCE=", the value below is configured in AboveTustin"
            fi
        elif [[ -f /etc/default/dump1090-mutability ]]; then
            RECEIVER_LONGITUDE=$(GetConfig "LON" "/etc/default/dump1090-mutability")
            RECEIVER_LONGITUDE_SOURCE=", the value below is configured in Dump1090"
        fi
        RECEIVER_LONGITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${RECEIVER_LONGITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's longitude${RECEIVER_LONGITUDE_SOURCE}:\n" 10 78 -- "${RECEIVER_LONGITUDE}" 3>&1 1>&2 2>&3)
        RECEIVER_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
    done
fi

## START INSTALLATION

echo -e ""
echo -e "\e[95m  Commencing installation...\e[97m"
echo -e ""

# Confirm timezone.
if [[ -z "${TIME_ZONE}" ]] ; then
    echo -e "\e[94m  Confirming time zone...\e[97m"
    TIME_ZONE=`cat /etc/timezone 2>&1`
    TIME_ZONE_ESCAPED=`echo ${TIME_ZONE} | sed -e 's/\\//\\\\\//g'`
fi

## PROJECT BUILD DIRECTORY

# Create the build directory if it does not already exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY} ]] ; then
    echo -e "\e[94m  Creating the ADS-B Receiver Project build directory...\e[97m"
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY} 2>&1
fi

# Create a component directory within the build directory if it does not already exist.
if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/abovetustin" ]] ; then
    echo -e "\e[94m  Creating the directory ${RECEIVER_BUILD_DIRECTORY}/abovetustin...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/abovetustin 2>&1
fi

## SETUP PHANTOMJS IF IT DOES NOT ALREADY EXIST ON THIS DEVICE

if [[ "${PHANTOMJS_EXISTS}" = "false" ]] ; then
    if [[ "${PHANTOMJS_BINARY_AVAILABLE}" = "true" ]] ; then

        # DOWNLOAD THE PHANTOMJS BINARY

        echo -e ""
        echo -e "\e[95m  Downloading and installing the PhantomJS binary...\e[97m"
        echo -e ""

        # Enter the root of the project build directory.
        echo -e "\e[94m  Entering the build directory...\e[97m"
        cd ${RECEIVER_BUILD_DIRECTORY}/abovetustin 2>&1

        # Select the relevant PhantomJS binary.
        case ${CPU_ARCHITECTURE} in
            "armv7l")
                # Use the armv7l version of the PhantomJS binary from https://github.com/jprochazka/phantomjs-linux-armv7l.
                echo -e "\e[94m  Downloading the ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo -e ""
                PHANTOMJS_BINARY_URL="https://github.com/jprochazka/phantomjs-linux-armv7l/releases/download/${PHANTOMJS_VERSION}/phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2"
                ;;
            "x86_64")
                # Use the x86_64 version of the PhantomJS binary from the PhantomJS web site.
                echo -e "\e[94m  Downloading the official ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo -e ""
                PHANTOMJS_BINARY_URL="https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2"
                ;;
            "i686")
                # Use the i686 version of the PantomJS binary from the PhantomJS web site.
                echo -e "\e[94m  Downloading the official ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo -e ""
                PHANTOMJS_BINARY_URL="https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2"
                ;;
        esac

        # Download the PantomJS binary.
        if [[ -n "${PHANTOMJS_BINARY_URL}" ]] ; then
            curl -L "${PHANTOMJS_BINARY_URL}" -O 2>&1
            echo ""
        fi

        # Extract the files from the PhantomJS archive which was just downloaded.
        if [[ -f "phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2" ]] ; then
            echo -e "\e[94m  Extracting the PhantomJS binary archive...\e[97m"
            echo ""
            tar -vxj -f phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2 2>&1
            echo -e ""
            echo -e "\e[94m  Removing the PhantomJS binary archive...\e[97m"
            echo ""
            rm -vf phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar.bz2 2>&1
            echo -e ""
        else
            echo -e "\e[94m  Unable to extract the PhantomJS binary archive...\e[97m"
        fi

        # Move the binary into the /usr/bin directory and make it executable.
        if [[ -f "phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}/bin/phantomjs" ]] ; then
            echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
            echo -e ""
            sudo cp -v phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}/bin/phantomjs /usr/bin 2>&1
            echo ""
        else
            echo -e "\e[94m  Unable to copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        fi

        # Make the binary in /usr/bin executable.
        if [[ -f "/usr/bin/phantomjs" ]] ; then
            echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
            echo -e ""
            sudo chmod -v +x /usr/bin/phantomjs 2>&1
        else
            echo -e "\e[94m  Unable to make the file /usr/bin/phantomjs executable...\e[97m"
        fi

    else

        # BUILD PHANTOMJS

        echo -e ""
        echo -e "\e[95m  Building then placing the PhantomJS binary...\e[97m"
        echo -e ""

        # Download the source code.
        echo -e ""
        echo -e "\e[95m  Preparing the PhantomJS Git repository...\e[97m"
        echo -e ""
        if [[ -d "${RECEIVER_BUILD_DIRECTORY}/phantomjs" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/phantomjs/.git" ]] ; then
            # A directory with a git repository containing the source code already exists.
            echo -e "\e[94m  Entering the PhantomJS git repository directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY}/phantomjs 2>&1
            echo -e ""
            echo -e "\e[94m  Updating the local PhantomJS git repository...\e[97m"
            git pull --all 2>&1
            echo -e ""
        else
            # A directory containing the source code does not exist in the build directory.
            echo -e "\e[94m  Entering the build directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY}/phantomjs 2>&1
            echo -e ""
            if [[ -d "${RECEIVER_BUILD_DIRECTORY}/phantomjs" ]] ; then
                echo -e "\e[94m  Removing old PhantomJS build directory...\e[97m"
                rm -vrf "${RECEIVER_BUILD_DIRECTORY}/phantomjs" 2>&1
                echo -e ""
            fi
            echo -e "\e[94m  Cloning the PhantomJS git repository locally...\e[97m"
            echo -e ""
            git clone git://github.com/ariya/phantomjs.git "${RECEIVER_BUILD_DIRECTORY}/phantomjs" 2>&1
            echo -e ""
        fi

        # Enter the PhantomJS build directory if not already there.
        if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/phantomjs" ]] ; then
            echo -e "\e[94m  Entering the PhantomJS Git repository directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY}/phantomjs 2>&1
        fi

        # Checkout the proper branch then init and update the submodules.
        echo -e "\e[94m  Checking out the branch ${PHANTOMJS_VERSION}...\e[97m"
        echo -e ""
        git checkout ${PHANTOMJS_VERSION} 2>&1
        echo -e ""
        echo -e "\e[94m  Initializing Git submodules...\e[97m"
        echo -e ""
        git submodule init 2>&1
        echo -e ""
        echo -e "\e[94m  Updating Git submodules...\e[97m"
        echo -e ""
        git submodule update 2>&1
        echo -e ""

        # Compile and link the code.
        if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
            # Limit the amount of processors being used on Raspberry Pi devices.
            # Not doing will very likely cause the compile to fail due to an out of memory error.
            echo -e "\e[94m  Building PhantomJS... \(Job will be limited to using 1 processor.\)\e[97m"
            python build.py -j 1 2>&1
        else
            echo -e "\e[94m  Building PhantomJS...\e[97m"
            python build.py 2>&1
        fi
        echo -e ""

        # Test that the binary was built properly.
        if [[ ! -f "bin/pahntomjs" ]] || [[ ! "`bin/phantomjs --version`" = "${PHANTOMJS_VERSION}" ]] ; then
            # If the dump978 binaries could not be found halt setup.
            echo -e ""
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  THE PHANTOMJS BINARIES BUILD APPEARS TO HAVE FAILED."
            echo -e "  SETUP HAS BEEN TERMINATED!"
            echo -e ""
            echo -e "\e[93mThe PhantomJS binary appear to have not been built successfully..\e[39m"
            echo -e ""
            echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
            echo -e "\e[92m  AboveTustin setup halted.\e[39m"
            echo -e ""
            read -p "Press enter to continue..." CONTINUE
            exit 1
        fi

        # Move the binary into the /usr/bin directory and make it executable.
        echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        sudo cp -v bin/phantomjs /usr/bin 2>&1
        echo ""
        echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
        sudo chmod -v +x /usr/bin/phantomjs 2>&1

    fi
fi

## INSTALL THE NEEDED PYTHON MODULES

echo -e ""
echo -e "\e[95m  Setting up the required Python modules...\e[97m"
echo -e ""

# Upgrade pip.
echo -e "\e[94m  Upgrading pip...\e[97m"
echo -e ""
sudo pip3 install --upgrade pip 2>&1
echo -e ""
echo -e "\e[94m  Upgrading virtualenv...\e[97m"
echo -e ""
sudo pip3 install --upgrade virtualenv 2>&1
echo -e ""

# Install Python modules.
echo -e "\e[94m  Installing the selenium Python module...\e[97m"
echo -e ""
sudo pip3 install selenium 2>&1
echo -e ""
echo -e "\e[94m  Installing the twitter Python module...\e[97m"
echo -e ""
sudo pip3 install twitter 2>&1
echo -e ""
echo -e "\e[94m  Installing the python-dateutil Python module...\e[97m"
echo -e ""
sudo pip3 install python-dateutil 2>&1
echo -e ""

## DOWNLOAD SOURCE

echo -e "\e[95m  Downloading and configuring AboveTustin...\e[97m"
echo -e ""

echo -e "\e[94m  Checking if the Git repository has been cloned...\e[97m"
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the local AboveTustin git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin 2>&1
    echo -e ""
    echo -e "\e[94m  Updating the local AboveTustin git repository...\e[97m"
    echo ""
    git pull 2>&1
    echo -e ""
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the AboveTustin build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/abovetustin 2>&1
    if [[ -d "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin" ]] ; then
        echo -e "\e[94m  Removing old build directory...\e[97m"
        rm -vrf "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin" 2>&1
        echo -e ""
    fi
    echo -e "\e[94m  Cloning the AboveTustin git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/kevinabrandon/AboveTustin.git "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin" 2>&1
    echo -e ""
fi

if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin" ]] ; then
    echo -e "\e[94m  Entering the AboveTustin git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin 2>&1
fi

## BUILD AND INSTALL

## APPLY CONFIGURATION

# Copy the file config.sample.ini to config.ini
if [[ -s "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" ]] ; then
    echo -e "\e[94m  Found existing configuration file config.ini...\e[97m"
elif [[ -s "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.sample.ini" ]] ; then
    echo -e "\e[94m  Copying the file config.sample.ini to the file config.ini...\e[97m"
    echo ""
    cp -v ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.sample.ini ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini 2>&1
    echo ""
else
    echo -e "\e[94m  Unable to install configuration file config.ini...\e[97m"
fi

# Write out the supplied values to the file config.ini.
if [[ -n "${TWITTER_ACCESS_TOKEN}" ]] ; then
    echo -e "\e[94m  Writing Twitter token value to the config.ini file...\e[97m"
    ChangeConfig access_token ${TWITTER_ACCESS_TOKEN} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_ACCESS_TOKEN_SECRET}" ]] ; then
    echo -e "\e[94m  Writing Twitter token secret value to the config.ini file...\e[97m"
    ChangeConfig access_token_secret ${TWITTER_ACCESS_TOKEN_SECRET} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_CONSUMER_KEY}" ]] ; then
    echo -e "\e[94m  Writing Twitter consumer key value to the config.ini file...\e[97m"
    ChangeConfig consumer_key ${TWITTER_CONSUMER_KEY} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_CONSUMER_SECRET}" ]] ; then
    echo -e "\e[94m  Writing Twitter consumer secret to the config.ini file...\e[97m"
    ChangeConfig consumer_secret ${TWITTER_CONSUMER_SECRET} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${TIME_ZONE_ESCAPED}" ]] ; then
    echo -e "\e[94m  Writing receiver timezone to the config.ini file...\e[97m"
    ChangeConfig time_zone ${TIME_ZONE_ESCAPED} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${RECEIVER_LATITUDE}" ]] ; then
    echo -e "\e[94m  Writing receiver latitude to the config.ini file...\e[97m"
    ChangeConfig latitude ${RECEIVER_LATITUDE} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi
if [[ -n "${RECEIVER_LONGITUDE}" ]] ; then
    echo -e "\e[94m  Writing receiver longitude to the config.ini file...\e[97m"
    ChangeConfig longitude ${RECEIVER_LONGITUDE} "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini"
fi

# Quick fix to remove quotes from config.
sed -e 's/= "/= /g' -e 's/"$//g' -i "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/config.ini" 2>&1

## CREATE SCRIPTS

# Add the run_tracker.sh script to /etc/rc.local so it is executed at boot up.
echo -e "\e[94m  Checking if the AboveTustin startup line is contained within the file /etc/rc.local...\e[97m"
if [[ `grep -cFx "${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/run_tracker.sh &" /etc/rc.local` -eq 0 ]] ; then
    echo -e "\e[94m  Adding the AboveTustin startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/run_tracker.sh &\n" /etc/rc.local
fi

## START SCRIPTS

echo -e ""
echo -e "\e[95m  Starting AboveTustin...\e[97m"
echo -e ""

# Kill any currently running AboveTustin related processes.
echo -e "\e[94m  Checking for any running AboveTustin processes...\e[97m"
if [[ $(ps -aux | grep '[r]un_tracker.sh' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current run_tracker.sh process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[r]un_tracker.sh' | awk '{print $2}') &> /dev/null
fi
if [[ $(ps -aux | grep '[t]racker.py' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current tracker.py process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[t]racker.py' | awk '{print $2}') &> /dev/null
fi
if [[ $(ps -aux | grep '[p]hantomjs' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current phantomjs process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[p]hantomjs' | awk '{print $2}') &> /dev/null
fi

# Start the run_tracker.sh script.
echo -e "\e[94m  Executing the run_tracker.sh script...\e[97m"
sudo nohup ${RECEIVER_BUILD_DIRECTORY}/abovetustin/AboveTustin/run_tracker.sh > /dev/null 2>&1 &

## SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  AboveTustin setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]]; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0
