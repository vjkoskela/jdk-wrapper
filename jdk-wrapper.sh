#!/bin/sh

# Copyright 2016 Ville Koskela
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ** DISCLAIMER **
#
# By using this script you agree to the license agreement specified for all
# versions of the JDK you invoke this script for. The author(s) assume no
# responsibility for compliance with this license agreement.

# ** USAGE **
#
# **IMPORTANT**: Sometime in May 2017 Oracle started requiring an Oracle Technology
# Network (OTN) account for downloading anything but the latest JDK version. To work
# around this either:
#
#   1) Manually download and cache the JDKs elsewhere (e.g. Artifactory, Nexus, S3, etc.) and use the `JDKW_SOURCE` to specify the location. For example:
#
#       > JDKW_SOURCE='http://artifactory.example.com/jdk/jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}' JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
#   2) Specify OTN credentials using the `JDKW_USERNAME` and `JDKW_PASSWORD` arguments to specify credentials. For example:
#
#       > JDKW_USERNAME=me@example.com JDKW_PASSWORD=secret JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
# If the JDK is not found in the local cache then it an attempt will be made to
# download it from OTN regardless of whether a login/password was provided. You
# will likely want developers (or some subset of developers) using the OTN
# login version via the __.jdkw__ file in their home directory (e.g. for testing
# JDK upgrades before making them available) while other developers and headless
# builds (e.g. Jenkins, Travis, Code Build, etc.) use a cached version. As with
# any use of this script **you** are responsible for compliance with the Oracle
# JDK license agreement and the OTN end user license agreement and any other
# agreements to which you are bound.
#
# Simply set your desired JDK and wrap your command relying on the JDK
# with a call to the jdk_wrapper.sh script.
#
# e.g.
# > JDKW_VERSION=8u65 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
# You can also set global values with a .jdkw properties file in your home
# directory or alternatively create a file called .jdkw in the working directory
# with the configuration properties. In either case the format is:
#
# e.g.
# JDKW_VERSION=8u65
# JDKW_BUILD=b13
#
# Then wrap your command:
#
# e.g.
# > jdk-wrapper.sh <CMD>
#
# The third option is to pass arguments to jdk-wrapper.sh which define the
# configuration. Any argument that begins with "JDKW_" will be considered a
# configuration parameter, everything from the first non-configuration parameter
# onward is considered part of the command.
#
# e.g.
# > jdk-wrapper.sh JDKW_VERSION=8u65 JDKW_BUILD=b13 <CMD>
#
# Finally, any combination of these four forms of configuration is permissible.
# The order of precedence from highest to lowest is:
#
#   1) Command Line
#   2) .jdkw (working directory)
#   3) ~/.jdkw (home directory)
#   4) Environment
#
# The wrapper script will download, cache and set JAVA_HOME before executing
# the specified command.
#
# Configuration via environment variables or property file:
#
# JDKW_VERSION : Version identifier (e.g. 8u65). Required.
# JDKW_BUILD : Build identifier (e.g. b17). Required.
# JDKW_TOKEN : Download token (e.g. e9e7ea248e2c4826b92b3f075a80e441). Optional.
# JDKW_JCE : Include Java Cryptographic Extensions (e.g. false). Optional.
# JDKW_TARGET : Target directory (e.g. /var/tmp). Optional.
# JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
# JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.
# JDKW_SOURCE : Source url format for download. Optional.
# JDKW_USERNAME: Username for OTN sign-on. Optional.
# JDKW_PASSWORD: Password for OTN sign-on. Optional.
# JDKW_VERBOSE : Log wrapper actions to standard out. Optional.
#
# By default the Java Cryptographic Extensions are included*.
# By default the target directory is ~/.jdk.
# By default the platform is detected using uname.
# By default the extension dmg is used for Darwin and tar.gz for Linux/Solaris.
# By default the source url is from Oracle</br>
# By default the wrapper does not log.
#
# * As of JDK version 9 the Java Cryptographic Extensions are bundled with the
# JDK and are not downloaded separately. Therefore, the value of JDKW_JCE is
# ignored for JDK 9.
#
# IMPORTANT: The JDKW_TOKEN is required for release 8u121-b13 and newer but
# is not required for JDK 9.0.1 or newer (as of 10/30/17).

log_err() {
  l_prefix=$(date  +'%H:%M:%S')
  printf "[%s] %s\n" "${l_prefix}" "$@" 1>&2;
}

log_out() {
  if [ -n "${JDKW_VERBOSE}" ]; then
    l_prefix=$(date  +'%H:%M:%S')
    printf "[%s] %s\n" "${l_prefix}" "$@"
  fi
}

rand() {
  awk 'BEGIN {srand();printf "%d\n", (rand() * 10^8);}'
}

safe_command() {
  l_command=$1
  log_out "${l_command}";
  eval $1
  l_result=$?
  if [ "${l_result}" -ne "0" ]; then
    log_err "ERROR: ${l_command} failed with ${l_result}"
    exit 1
  fi
}

generate_manifest_checksum() {
  l_path=$1
  checksum_exec="exit 1"
  if command -v md5 > /dev/null; then
    checksum_exec="md5"
  elif command -v sha1sum > /dev/null; then
    checksum_exec="sha1sum"
  fi
  l_escaped_path=$(printf '%s' "${l_path}" | sed -e 's@/@\\\/@g')
  echo $(find "${l_path}" -type f \( -iname "*" ! -iname "manifest.checksum" \) -print0 |  xargs -0 ls -l | awk '{print $5, $9}' | sort | sed 's/^\([0-9]*\) '"${l_escaped_path}"'\/\(.*\)$/\1 \2/' | ${checksum_exec})
}

encode() {
  l_value="$1"
  l_encoded_value=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${l_value}" "")
  echo "${l_encoded_value##/?}"
}

otn_extract() {
  l_file=$1
  echo $(grep -o '<[^<]*input[^>]*.' "${l_file}" | grep 'type="hidden"' | sed '/.*name="\([^"]*\)"[ ]*value="\([^"]*\)".*/!d;s//\1=\2/' | xargs -I {} curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "{}" "" | sed 's/\/?\([^\/?]*\)/\1\&/g')
}

otn_signon() {
  l_username=$(encode "userid=$1")
  l_password=$(encode "pass=$2")

  l_cookiejar="${TMPDIR:-/tmp}/otn.cookiejar-$$.$(rand)"
  l_redirectform="${TMPDIR:-/tmp}/otn.redirectform-$$.$(rand)"
  l_signon="${TMPDIR:-/tmp}/otn.signon-$$.$(rand)"
  l_credsubmit="${TMPDIR:-/tmp}/otn.credsubmit-$$.$(rand)"

  if [ -f "${l_cookiejar}" ]; then
    rm -f "${l_cookiejar}"
  fi

  # Download the homepage
  log_out "OTN Login: Getting homepage..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -o /dev/null https://www.oracle.com

  # Download and parse the redirect
  log_out "OTN Login: Getting redirect..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_redirectform}" http://www.oracle.com/webapps/redirect/signon?nexturl=https://www.oracle.com/index.html?
  redirect_data=$(otn_extract "${l_redirectform}")

  # Redirect to the sign-on form
  log_out "OTN Login: Getting sign-on..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_signon}" -d "${redirect_data}" https://login.oracle.com:443/oaam_server/oamLoginPage.jsp
  signon_data=$(otn_extract "${l_signon}")
  signon_data="${signon_data}${l_username}&"
  signon_data="${signon_data}&${l_password}&"

  # Post the sign-on form
  log_out "OTN Login: Posting login..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/oamLoginPage.jsp -o /dev/null https://login.oracle.com:443/oaam_server/loginAuth.do

  # Add the accept cookie to the jar
  printf ".oracle.com\tTRUE\t/\tFALSE\t0\toraclelicense\taccept-securebackup-cookie\n" >> "${l_cookiejar}"

  # Complete the sign-on
  log_out "OTN Login: Completing login..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/loginAuth.do -o "${l_credsubmit}" https://login.oracle.com:443/oaam_server/authJump.do?jump=false
  credsubmit_data=$(otn_extract "${l_credsubmit}")

  sleep 3
  
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${credsubmit_data}" --referer https://login.oracle.com:443/oaam_server/authJump.do -o /dev/null https://login.oracle.com:443/oam/server/dap/cred_submit

  # Return the filled cookie jar
  rm "${l_redirectform}"
  rm "${l_signon}"
  OTN_COOKIE_JAR="${l_cookiejar}"
}

# Default curl options
CURL_OPTIONS=""

# Default user agent
OTN_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'

# Load properties file in home directory
if [ -f "${HOME}/.jdkw" ]; then
  . "${HOME}/.jdkw"
fi

# Load properties file in working directory
if [ -f ".jdkw" ]; then
  . "./.jdkw"
fi

# Process command line arguments
IN_COMMAND=
COMMAND=
for ARG in "$@"; do
  if [ ! -z ${IN_COMMAND} ]; then
    COMMAND="${COMMAND} \"${ARG}\""
  else
    JDKW_ARG=$(echo "${ARG}" | grep 'JDKW_.*')
    if [ -n "${JDKW_ARG}" ]; then
      eval ${ARG}
    else
      IN_COMMAND=1
      COMMAND="\"${ARG}\""
    fi
  fi
done

# Process configuration
if [ -z "${JDKW_VERSION}" ]; then
  log_err "Required JDKW_VERSION (e.g. 8u65) environment variable not set"
  exit 1
fi
JAVA_MAJOR_VERSION=$(echo "${JDKW_VERSION}" | sed 's/\([0-9]*\).*/\1/')
if [ -z "${JDKW_BUILD}" ]; then
  log_err "Required JDKW_BUILD (e.g. b17) environment variable not set"
  exit 1
fi
if [ "${JAVA_MAJOR_VERSION}" = "9" ]; then
  JDKW_JCE=
  log_out "Forced to no jce"
elif [ -z "${JDKW_JCE}" ]; then
  JDKW_JCE="true"
  log_out "Defaulted to jce ${JDKW_JCE}"
fi
if [ -z "${JDKW_TARGET}" ]; then
  JDKW_TARGET="${HOME}/.jdk"
  log_out "Defaulted to target ${JDKW_TARGET}"
fi
if [ -z "${JDKW_PLATFORM}" ]; then
  os=$(uname)
  architecture=$(uname -m)
  if [ $? -ne 0 ]; then
    log_err "Optional JDKW_PLATFORM (e.g. macosx-x64) environment variable not set and unable to determine a reasonable default"
    exit 1
  else
    if [ "${os}" = "Darwin" ]; then
      if [ "${JAVA_MAJOR_VERSION}" = "9" ]; then
        JDKW_PLATFORM="osx-x64"
      else
        JDKW_PLATFORM="macosx-x64"
      fi
    elif [ "${os}" = "Linux" ]; then
      if [ "${architecture}" = "x86_64" ]; then
        JDKW_PLATFORM="linux-x64"
      else
        JDKW_PLATFORM="linux-i586"
      fi
    elif [ "${os}" = "SunOS" ]; then
      if [ "${architecture}" = "sparc64" ]; then
        JDKW_PLATFORM="solaris-sparcv9"
      elif [ "${architecture}" = "sun4u" ]; then
        JDKW_PLATFORM="solaris-sparcv9"
      else
        JDKW_PLATFORM="solaris-x64"
      fi
    else
      log_err "Optional JDKW_PLATFORM (e.g. macosx-x64) environment variable not set and unable to determine a reasonable default"
      exit 1
    fi
    log_out "Detected platform ${JDKW_PLATFORM}"
  fi
fi
extension="tar.gz"
if [ "${JDKW_PLATFORM}" = "macosx-x64" ]; then
  extension="dmg"
elif [ "${JDKW_PLATFORM}" = "osx-x64" ]; then
  extension="dmg"
fi
if [ -z "${JDKW_EXTENSION}" ]; then
  JDKW_EXTENSION=${extension}
  log_out "Defaulted to extension ${JDKW_EXTENSION}"
fi
if [ -z "${JDKW_VERBOSE}" ]; then
  CURL_OPTIONS="${CURL_OPTIONS} --silent"
fi

# Default JDK locations
if [ "${JAVA_MAJOR_VERSION}" = "9" ]; then
  LATEST_JDKW_SOURCE='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
  ARCHIVED_JDKW_SOURCE='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
else
  LATEST_JDKW_SOURCE='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
  ARCHIVED_JDKW_SOURCE='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
fi

# Ensure target directory exists
if [ ! -d "${JDKW_TARGET}" ]; then
  log_out "Creating target directory ${JDKW_TARGET}"
  safe_command "mkdir -p \"${JDKW_TARGET}\""
fi

# Build jdk identifier
jdkid="${JDKW_VERSION}_${JDKW_BUILD}_${JDKW_PLATFORM}"
if [ "${JDKW_JCE}" = "true" ]; then
  jdkid="${jdkid}_jce"
fi

# Check the JDK contents have not changed
manifest="${JDKW_TARGET}/${jdkid}/manifest.checksum"
if [ -f "${JDKW_TARGET}/${jdkid}/environment" ]; then
  if [ -f "${manifest}" ]; then
    log_out "Verifying manifest integrity..."
    manifest_current="${TMPDIR:-/tmp}/${jdkid}-$$.$(rand)"
    generate_manifest_checksum "${JDKW_TARGET}/${jdkid}" > "${manifest_current}"
    manifest_checksum=$(cat "${manifest}")
    manifest_current_checksum=$(cat "${manifest_current}")
    log_out "Previous: ${manifest_checksum}"
    log_out "Current: ${manifest_current_checksum}"
    safe_command "rm -f \"${manifest_current}\""
    if [ "${manifest_checksum}" != "${manifest_current_checksum}" ]; then
      log_out "Manifest checksum changed; preparing to reinstall"
      safe_command "rm -f \"${JDKW_TARGET}/${jdkid}/environment\""
    else
      log_out "Manifest integrity verified."
    fi
  else
    log_out "Manifest checksum not found; preparing to reinstall"
    safe_command "rm -f \"${JDKW_TARGET}/${jdkid}/environment\""
  fi
fi

# Download and install desired jdk version
if [ ! -f "${JDKW_TARGET}/${jdkid}/environment" ]; then
  log_out "Desired JDK version ${jdkid} not found"
  if [ -d "${JDKW_TARGET}/${jdkid}" ]; then
    safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
  fi

  # Create target directory
  LAST_DIR=$(pwd)
  safe_command "mkdir -p \"${JDKW_TARGET}/${jdkid}\""
  safe_command "cd \"${JDKW_TARGET}/${jdkid}\""

  # JDK
  token_segment=""
  if [ -n "${JDKW_TOKEN}" ]; then
    token_segment="${JDKW_TOKEN}/"
  fi
  jdk_archive="jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}"

  # Download archive
  download_result=-1
  if command -v curl > /dev/null; then
    # Do NOT execute with safe_command; undo operations below on failure

    # 1) Attempt download from user specified source
    if [ -n "${JDKW_SOURCE}" ]; then
      eval "jdk_url=\"${JDKW_SOURCE}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      curl ${CURL_OPTIONS} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 2) Attempt download from latest source
    if [ ${download_result} != 0 ]; then
      eval "jdk_url=\"${LATEST_JDKW_SOURCE}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      curl ${CURL_OPTIONS} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 3) Attempt download from archive source
    if [ ${download_result} != 0 ]; then
      eval "jdk_url=\"${ARCHIVED_JDKW_SOURCE}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      if [ -z "${JDKW_USERNAME}" ]; then
        log_err "No username specified; aborting..."
      elif [ -z "${JDKW_PASSWORD}" ]; then
        log_err "No password specified; aborting..."
      else
        otn_signon "${JDKW_USERNAME}" "${JDKW_PASSWORD}"
        log_out "Initiating authenticated download..."
        curl ${CURL_OPTIONS} -f -k -L -H "User-Agent:${OTN_USER_AGENT}" -b "${OTN_COOKIE_JAR}" -o "${jdk_archive}" "${jdk_url}"
        download_result=$?
      fi
    fi
  else
    log_err "Could not find curl; aborting..."
    download_result=-1
  fi
  if [ ${download_result} != 0 ]; then
    log_err "Download failed!"
    safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
    safe_command "cd ${LAST_DIR}"
    exit 1
  fi

  # Extract based on extension
  log_out "Unpacking ${JDKW_EXTENSION}..."
  if [ "${JDKW_EXTENSION}" = "tar.gz" ]; then
    safe_command "tar -xzf \"${jdk_archive}\""
    safe_command "rm -f \"${jdk_archive}\""
    package=$(ls | grep "jdk.*" | head -n 1)
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/${package}"
  elif [ "${JDKW_EXTENSION}" = "dmg" ]; then
    result=$(hdiutil attach "${jdk_archive}" | grep "/Volumes/.*")
    volume=$(echo "${result}" | grep -o "/Volumes/.*")
    mount=$(echo "${result}" | grep -o "/dev/[^ ]*" | tail -n 1)
    package=$(ls "${volume}" | grep "JDK.*\.pkg" | head -n 1)
    safe_command "xar -xf \"${volume}/${package}\" . &> /dev/null"
    safe_command "hdiutil detach \"${mount}\" &> /dev/null"
    jdk=$(ls | grep "jdk.*\.pkg" | head -n 1)
    safe_command "cpio -i < \"./${jdk}/Payload\" &> /dev/null"
    safe_command "rm -f \"${jdk_archive}\""
    safe_command "rm -rf \"${jdk}\""
    safe_command "rm -rf \"javaappletplugin.pkg\""
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/Contents/Home"
  else
    log_err "Unsupported extension ${JDKW_EXTENSION}"
    safe_command "cd ${LAST_DIR}"
    exit 1
  fi
  printf "export JAVA_HOME=\"%s\"\n" "${JAVA_HOME}" > "${JDKW_TARGET}/${jdkid}/environment"
  printf "export PATH=\"\$JAVA_HOME/bin:\$PATH\"\n" >> "${JDKW_TARGET}/${jdkid}/environment"

  # Download and install matching JCE version
  if [ "${JDKW_JCE}" = "true" ]; then
    # JCE
    jce_url="http://download.oracle.com/otn-pub/java/jce/${JAVA_MAJOR_VERSION}/jce_policy-${JAVA_MAJOR_VERSION}.zip"
    jce_archive="jce_policy-${JAVA_MAJOR_VERSION}.zip"

    # Download archive
    log_out "Downloading JCE from ${jce_url}"
    download_result=
    if command -v curl > /dev/null; then
      # Do NOT execute with safe_command; undo operations below on failure
      curl ${CURL_OPTIONS} -j -k -L -H "Cookie: gpw_e24=xxx; oraclelicense=accept-securebackup-cookie;" -o "${jce_archive}" "${jce_url}"
      download_result=$?
    else
      log_err "Could not find curl; aborting..."
      download_result=-1
    fi
    if [ ${download_result} -ne 0 ]; then
      log_err "Download failed of ${jce_url}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      safe_command "cd ${LAST_DIR}"
      exit 1
    fi

    # Extract contents
    safe_command "unzip -qq \"${jce_archive}\""
    safe_command "find \"./UnlimitedJCEPolicyJDK${JAVA_MAJOR_VERSION}\" -type f -exec cp {} \"${JAVA_HOME}/jre/lib/security\" \\;"
    safe_command "rm -rf \"./UnlimitedJCEPolicyJDK${JAVA_MAJOR_VERSION}\""
    safe_command "rm \"${jce_archive}\""
  fi

  # Installation complete
  generate_manifest_checksum "${JDKW_TARGET}/${jdkid}" > "${manifest}"
  safe_command "cd ${LAST_DIR}"
fi

# Setup the environment
log_out "Environment:"
if [ -n "${JDKW_VERBOSE}" ]; then
  cat "${JDKW_TARGET}/${jdkid}/environment"
fi
. "${JDKW_TARGET}/${jdkid}/environment"

# Execute the provided command
log_out "Executing: ${COMMAND}"
eval ${COMMAND}
ret=$?

# Output deprecation notice
printf "\e[0;31m[IMPORTANT]\e[0m This version of JDK Wrapper is end of life.\n"
printf "\e[0;32mUpgrade to the new version by following this migration guide:\e[0m\n"
printf "https://github.com/KoskiLabs/jdk-wrapper/blob/master/MIGRATION.md"

exit ${ret}
