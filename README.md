jdk-wrapper
===========

__DISCLAIMER__

_By using this script you agree to the license agreement specified for all
versions of the Oracle JDK you invoke this script for. The author(s) assume no
responsibility for compliance with the Oracle JDK license agreement. Please see [LICENSE](LICENSE) for additional conditions of use._

Provides automatic download, unpacking and usage of specific Oracle JDK versions to faciliate repeatable builds of Java based software.

Usage
-----

Simply set your desired JDK version and wrap your command relying on the JDK
with a call to the jdk-wrapper.sh script.

    > JDKW_VERSION=8u65 JDKW_BUILD=13 jdk-wrapper.sh <CMD>

The wrapper script will download and cache the specified JDK version and set JAVA_HOME appropriately before executing the specified command.

### Configuration

Configuration is performed using environment variables:

* JDKW_VERSION : Version identifier (e.g. 8u65). Required.
* JDKW_BUILD : Build identifier (e.g. b17). Required.
* JDKW_TARGET : Target directory (e.g. /var/tmp). Optional.
* JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
* JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.

The default target directory is ~/.jdk.
The default platform is detected using uname.
By default the extension dmg is used for Darwin and tar.gz for other platforms.

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

The Oracle JDK versions specified over all invocations of the jdk-wrapper.sh script are cached in the directory specified by JDKW_TARGET environment variable in perpetuity. It is recommended that you purge the cache periodically.

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
- JDKW_VERSION=8u65
- JDKW_BUILD=17
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

License
-------

Published under Apache Software License 2.0, see LICENSE

&copy; Ville Koskela, 2016

