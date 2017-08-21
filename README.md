jdk-wrapper
===========

__DISCLAIMER__

_By using this script you agree to the license agreement specified for all
versions of the Oracle JDK you invoke this script for. The author(s) assume no
responsibility for compliance with the Oracle JDK license agreement. Please see
[LICENSE](LICENSE) for additional conditions of use._

<a href="https://travis-ci.org/vjkoskela/jdk-wrapper/">
    <img src="https://travis-ci.org/vjkoskela/jdk-wrapper.png"
         alt="Travis Build">
</a>

Provides automatic download, unpacking and usage of specific Oracle JDK versions to faciliate repeatable builds of Java based software.

**IMPORTANT**: Sometime in May 2017 Oracle started requiring an Oracle Technology Network (OTN) account for downloading anything but the latest 
JDK version. To work around this either:
 
 1) Manually download and cache the JDKs elsewhere (e.g. Artifactory, Nexus, S3, etc.) and use the `JDKW_SOURCE` to specify the location. For example:

    > JDKW_SOURCE='http://artifactory.example.com/jdk/jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}' JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
 
 2) Specify OTN credentials by using the `JDKW_USERNAME` and `JDKW_PASSWORD` arguments. For example:
                                                                                                    
    > JDKW_USERNAME=me@example.com JDKW_PASSWORD=secret JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>

If the JDK is not found in the local cache, then an attempt is made to download it from the user specified source if provided. If that attempt fails or is skipped,
the next attempt uses the publicly available endpoint at Oracle (where only the latest version is available). If that attempt fails, the final step uses
the OTN credentials to login and attempt download via the secure OTN endpoint at Oracle if credentials were provided. 

You will likely want developers (or some subset of developers) using the OTN login version via the __.jdkw__ file in their home directory (e.g. for testing
JDK upgrades before making them available) while other developers and headless builds (e.g. Jenkins, Travis, Code Build, etc.) use your private cloud/on-prem cached version. As with
any use of this script **you** are responsible for compliance with the Oracle JDK license agreement and the OTN end user license agreement and any other
agreements to which you are bound.

Usage
-----

Simply set your desired JDK version and wrap your command relying on the JDK with a call to the jdk-wrapper.sh script.

    > JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441 jdk-wrapper.sh <CMD>

You can also set global values with a .jdkw properties file in your home directory.

```
JDKW_VERSION=8u121
JDKW_BUILD=b13
JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

Alternatively, create a .jdkw properties file in the working directory.

```
JDKW_VERSION=8u131
JDKW_BUILD=b11
JDKW_TOKEN=d54c1d3a095b4ff2b6607d096fa80163
```

Then execute jdk-wrapper.sh script without setting the environment variables.

    > jdk-wrapper.sh <CMD>

The third option is to pass arguments to jdk-wrapper.sh which define the configuration. Any argument that begins with "JDKW_" will be considered a configuration parameter, everything from the first non-configuration parameter onward is considered part of the command.

    > jdk-wrapper.sh JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441 <CMD>

Finally, any combination of these four forms of configuration is permissible. The order of precedence from highest to lowest is:

1) Command Line
2) .jdkw (working directory)
3) ~/.jdkw (home directory)
4) Environment

The wrapper script will download and cache the specified JDK version and set JAVA_HOME appropriately before executing the specified command.

### Configuration

Regardless of how the configuration is specified it supports the following:

* JDKW_VERSION : Version identifier (e.g. '8u65'). Required.
* JDKW_BUILD : Build identifier (e.g. 'b17'). Required.
* JDKW_TOKEN : Download token (e.g. e9e7ea248e2c4826b92b3f075a80e441). Optional.
* JDKW_JCE : Include Java Cryptographic Extensions (e.g. false). Optional.
* JDKW_TARGET : Target directory (e.g. '/var/tmp'). Optional.
* JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
* JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.
* JDKW_SOURCE : Source url format for download. Optional.
* JDKW_USERNAME: Username for OTN sign-on. Optional.
* JDKW_PASSWORD: Password for OTN sign-on. Optional.
* JDKW_VERBOSE : Log wrapper actions to standard out. Optional.

The default target directory is ~/.jdk.<br/>
The default platform is detected using uname.<br/>
By default the Java Cryptographic Extensions are included.<br/>
By default the extension dmg is used for Darwin and tar.gz for other platforms.<br/>
By default the source url is from Oracle</br>
By default the wrapper does not log.

**IMPORTANT**: The JDKW_TOKEN is required for release 8u121-b13 and newer.

### Version and Build

The desired version and build of the Oracle JDK may be determined as follows:

* Browse to the [Java SE Downloads](http://www.oracle.com/technetwork/java/javase/downloads/index.html) page.
* Click the "JDK Download" button on the right.
* Locate the desired version.
* Accept the associated license agreement.
* Hover over one of the download links.

All the links contain a path element named {MAJOR}u{MINOR}-{BUILD}, for example _8u73-b02_ where _8u73_ would be used as the value for JDKW_VERSION and _b02_ the value for JDKW_BUILD. For versions 8u121-b13 and higher the link contains an alpha-numeric path segment that looks like _e9e7ea248e2c4826b92b3f075a80e441_ which needs to be set as the JDKW_TOKEN.

Archived versions of JDK8 are [listed here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html).

### Caching

The Oracle JDK versions specified over all invocations of the jdk-wrapper.sh script are cached in the directory specified by JDKW_TARGET environment variable in perpetuity. It is recommended that you purge the cache periodically to prevent it from growing unbounded.

### Travis

There are three changes necessary to use the jdk-wrapper.sh script in your Travis build. First, ensure that the JDKW_TARGET is configured as a cache directory:

```yml
cache:
  directories:
  - $HOME/.jdk
```

Second, configure the JDKW_VERSION and JDKW_BUILD environment variables to specify the Oracle JDK to use:

```yml
env:
  global:
  - JDKW_VERSION=8u121
  - JDKW_BUILD=b13
  - JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

To create a matrix build against multiple versions of the Oracle JDK simply specify the environment variables like this:

```yml
env:
  - JDKW_VERSION=7u79 JDKW_BUILD=b15
  - JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

Finally, invoke your build command using the jdk-wrapper script. The following assumes you have downloaded and included jdk-wrapper.sh in your project.

```yml
script:
- ./jdk-wrapper.sh mvn install
```

Alternatively, you may download the latest version and execute it as follows:

```yml
script:
- curl -s https://raw.githubusercontent.com/vjkoskela/jdk-wrapper/master/jdk-wrapper.sh | bash /dev/stdin mvn install
```

If your repository contains a .jdkw properties file it is __not__ sufficient to set the environment variables to create a matrix build because the .jdkw properties file will override the environment variables. Instead you must set the environment variables and then pass them as arguments to jdk-wrapper.sh as follows: 
 
```yml
script:
- ./jdk-wrapper.sh JDKW_VERSION=${JDKW_VERSION} JDKW_BUILD=${JDKW_BUILD} JDKW_TOKEN=${JDKW_TOKEN} mvn install
```

This is most commonly the case when you have a JDK version that you develop against (typically the latest) specified in .jdkw but desire a build which validates against multiple (older) JDK versions.

Prerequisites
-------------

The jdk-wrapper script may work with other versions or with suitable replacements but has been tested with these:

* posix shell: bash (4.4.12), BusyBox (1.25.1)
* awk (4.1.4)
* curl (7.51.0)
* grep (3.0)
* sed (4.4)
* sort (8.27)
* sha1sum (8.27) or md5

Plus tools for extracting files from the target archive type (e.g. tar.gz, dmg, etc.) such as gzip, tar or xar (for example).

License
-------

Published under Apache Software License 2.0, see LICENSE

&copy; Ville Koskela, 2016

