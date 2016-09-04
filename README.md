jdk-wrapper
===========

__DISCLAIMER__

_By using this script you agree to the license agreement specified for all
versions of the Oracle JDK you invoke this script for. The author(s) assume no
responsibility for compliance with the Oracle JDK license agreement. Please see [LICENSE](LICENSE) for additional conditions of use._

<a href="https://travis-ci.org/vjkoskela/jdk-wrapper/">
    <img src="https://travis-ci.org/vjkoskela/jdk-wrapper.png"
         alt="Travis Build">
</a>

Provides automatic download, unpacking and usage of specific Oracle JDK versions to faciliate repeatable builds of Java based software.

Usage
-----

Simply set your desired JDK version and wrap your command relying on the JDK with a call to the jdk-wrapper.sh script.

    > JDKW_VERSION=8u65 JDKW_BUILD=b17 jdk-wrapper.sh <CMD>

Alternatively, create a .jdkw properties file in the working directory.

```
JDKW_VERSION=8u65
JDKW_BUILD=b17
```

Then execute jdk-wrapper.sh script without setting the environment variables.

    > jdk-wrapper.sh <CMD>

The third option is to pass arguments to jdk-wrapper.sh which define the configuration. Any argument that begins with "JDKW_" will be considered a configuration parameter, everything from the first non-configuration parameter onward is considered part of the command.

    > jdk-wrapper.sh JDKW_VERSION=8u65 JDKW_BUILD=13 <CMD>

Finally, any combination of these three forms of configuration is permissible. Any environment variables override the values in the .jdkw file and any values specified on the command line override both the environment and the .jdkw file.

The wrapper script will download and cache the specified JDK version and set JAVA_HOME appropriately before executing the specified command.

### Configuration

Regardless of how the configuration is specified it supports the following:

* JDKW_VERSION : Version identifier (e.g. '8u65'). Required.
* JDKW_BUILD : Build identifier (e.g. 'b17'). Required.
* JDKW_JCE : Include Java Cryptographic Extensions (e.g. false). Optional.
* JDKW_TARGET : Target directory (e.g. '/var/tmp'). Optional.
* JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
* JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.
* JDKW_VERBOSE : Log wrapper actions to standard out. Optional.

The default target directory is ~/.jdk.<br/>
The default platform is detected using uname.<br/>
By default the Java Cryptographic Extensions are included.
By default the extension dmg is used for Darwin and tar.gz for other platforms.<br/>
By default the wrapper does not log.

### Version and Build

The desired version and build of the Oracle JDK may be determined as follows:

* Browse to the [Java SE Downloads](http://www.oracle.com/technetwork/java/javase/downloads/index.html) page.
* Click the "JDK Download" button on the right.
* Locate the desired version.
* Accept the associated license agreement.
* Hover over one of the download links.

All the links contain a path element named {MAJOR}u{MINOR}-{BUILD}, for example _8u73-b02_ where _8u73_ would be used as the value for JDKW_VERSION and _b02_ the value for JDKW_BUILD.

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
  - JDKW_VERSION=8u65
  - JDKW_BUILD=b17
```

To create a matrix build against multiple versions of the Oracle JDK simply specify the environment variables like this:

```yml
env:
  - JDKW_VERSION=7u79 JDKW_BUILD=b15
  - JDKW_VERSION=8u74 JDKW_BUILD=b02
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
- ./jdk-wrapper.sh JDKW_VERSION=${JDKW_VERSION} JDKW_BUILD=${JDKW_BUILD} mvn install
```

This is most commonly the case when you have a JDK version that you develop against (typically the latest) specified in .jdkw but desire a build which validates against multiple (older) JDK versions.

License
-------

Published under Apache Software License 2.0, see LICENSE

&copy; Ville Koskela, 2016

