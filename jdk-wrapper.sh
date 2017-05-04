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
# Simply set your desired JDK and wrap your command relying on the JDK
# with a call to the jdk_wrapper.sh script.
#
# e.g.
# > JDKW_VERSION=8u65 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
# Alternatively, create a file called .jdkw in the working directory with the
# configuration properties.
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
# Finally, any combination of these three forms of configuration is permissible.
# Any environment variables override the values in the .jdkw file and any values
# specified on the command line override both the environment and the file.
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
# JDKW_VERBOSE : Log wrapper actions to standard out. Optional.
#
# By default the Java Cryptographic Extensions are included.
# By default the target directory is ~/.jdk.
# By default the platform is detected using uname.
# By default the extension dmg is used for Darwin and tar.gz for Linux/Solaris.
# By default the wrapper does not log.
#
# IMPORTANT: The JDKW_TOKEN is required for release 8u121-b13 and newer.

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
  echo `find "${l_path}" -type f \( -iname "*" ! -iname "manifest.checksum" \) -print0 |  xargs -0 ls -l | awk '{print $5, $9}' | sort | ${checksum_exec}`
}

# Default curl/wget options
CURL_OPTIONS=""
WGET_OPTIONS=""

# Check latest JDK version
CHECK_JDK_SH="check-latest-jdk.sh"
CHECK_JDK_SOURCE="https://raw.githubusercontent.com/coreen/Bash/master/check-latest-jdk.sh"
CHECK_JDK_PATH="./${CHECK_JDK_SH}"
curl "${CHECK_JDK_SOURCE}" -o "${CHECK_JDK_SH}" --silent --location --connect-timeout 1 --max-time 1
if [ ! -f "${CHECK_JDK_PATH}" ]; then
  printf "ERROR: Unable to initialize check-jdk script\\n"
  exit 1
fi
chmod +x "${CHECK_JDK_PATH}"
./"${CHECK_JDK_PATH}"

# Load properties file
if [ -f .jdkw ]; then
  . ./.jdkw
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
if [ -z "${JDKW_BUILD}" ]; then
  log_err "Required JDKW_BUILD (e.g. b17) environment variable not set"
  exit 1
fi
if [ -z "${JDKW_JCE}" ]; then
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
      JDKW_PLATFORM="macosx-x64"
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
fi
if [ -z "${JDKW_EXTENSION}" ]; then
  JDKW_EXTENSION=${extension}
else
  log_out "Defaulted to extension ${JDKW_EXTENSION}"
fi
if [ -z "${JDKW_VERBOSE}" ]; then
  CURL_OPTIONS="${CURL_OPTIONS} --silent"
  WGET_OPTIONS="${WGET_OPTIONS} --quiet"
fi
JAVA_MAJOR_VERSION=$(echo "${JDKW_VERSION}" | sed 's/\([0-9]*\)u[0-9]*/\1/')

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
  jdk_url="http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}"
  jdk_archive="jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}"

  # Download archive
  log_out "Downloading JDK from ${jdk_url}"
  download_result=
  if command -v curl > /dev/null; then
    # Do NOT execute with safe_command; undo operations below on failure
    curl ${CURL_OPTIONS} -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
    download_result=$?
  elif command -v wget > /dev/null; then
    # Do NOT execute with safe_command; undo operations below on failure
    wget ${WGET_OPTIONS} --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -O "${jdk_archive}" "${jdk_url}"
    download_result=$?
  else
    log_err "Could not find curl or wget; aborting..."
    download_result=-1
  fi
  if [ ${download_result} -ne 0 ]; then
    log_err "Download failed of ${jdk_url}"
    safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
    safe_command "cd ${LAST_DIR}"
    exit 1
  fi

  # Extract based on extension
  log_out "Unpacking ${JDKW_EXTENSION}..."
  if [ "${JDKW_EXTENSION}" = "tar.gz" ]; then
    safe_command "tar -xzf \"${jdk_archive}\""
    package=$(ls | grep "jdk[^-].*" | head -n 1)
    safe_command "rm -f \"${jdk_archive}\""
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
    elif command -v wget > /dev/null; then
      # Do NOT execute with safe_command; undo operations below on failure
      wget ${WGET_OPTIONS} --no-check-certificate --no-cookies --header "Cookie: gpw_e24=xxx; oraclelicense=accept-securebackup-cookie;" -O "${jce_archive}" "${jce_url}"
      download_result=$?
    else
      log_err "Could not find curl or wget; aborting..."
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
log_out "Environment:\n$(cat "${JDKW_TARGET}/${jdkid}/environment")"
. "${JDKW_TARGET}/${jdkid}/environment"

# Execute the provided command
log_out "Executing: ${COMMAND}"
eval ${COMMAND}
exit $?
