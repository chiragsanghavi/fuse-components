# Camel SAP 4.10.2 on Linux x86_64

This guide installs the community Camel SAP component with:

- Apache Camel `4.10.2`
- SAP Java Connector (JCo) `3.1.13`
- SAP Java IDoc Library `3.1.4`
- the SAP JCo native library for 64-bit Linux x86_64

SAP JCo and SAP IDoc are licensed SAP software. Obtain them from SAP and do
not commit or redistribute their archives, JARs, or native libraries.

## Prerequisites

- A 64-bit x86_64 Linux environment
- JDK 17 for building this component
- Maven 3.8 or newer
- `bash`, `jar`, `tar`, and `file`
- access to Maven Central

Confirm the runtime architecture:

```bash
uname -m
java -XshowSettings:properties -version 2>&1 | grep -E 'os.name|os.arch|java.version'
```

`uname -m` and `os.arch` must identify x86_64/amd64. SAP JCo native libraries
must match the JVM architecture.

## Obtain SAP software

Place the AS400 JCo and platform-neutral IDoc ZIPs already used by this fork
under `reference/`:

```text
reference/sapjco31P_13-70004561.zip
reference/sapjidoc31P_4-80004914.zip
```

Also download SAP JCo `3.1.13` for Linux x86_64. The installer accepts any of:

- the SAP Linux download ZIP containing its Linux TGZ
- the extracted Linux `.tgz`, `.tar.gz`, or `.tar`
- the extracted Linux x86_64 `libsapjco3.so`

The Linux package must be the same JCo version as `sapjco3.jar`: `3.1.13`.

## Install SAP artifacts into Maven

Pass the Linux package as the second argument. The first argument is the
directory containing the two fixed ZIP names above:

```bash
./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh \
  reference /secure/downloads/SAP-JCo-linux-x86_64.zip
```

For a private Maven repository:

```bash
MAVEN_REPO_LOCAL=/path/to/maven/repository \
  ./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh \
  reference /secure/downloads/SAP-JCo-linux-x86_64.zip
```

The script verifies that the native library is an ELF 64-bit x86-64 binary
and installs:

```text
com.sap.conn.jco:sapjco3:jar:3.1.13
com.sap.conn.idoc:sapidoc3:jar:3.1.4
com.sap.conn.jco:sapjco3:so:linux-x86_64:3.1.13
```

It also installs the AS400 artifacts because the same local repository can
then build either supported platform.

## Build

Build the component and Linux OSGi fragment:

```bash
mvn -Prepository-linux -DskipTests clean install
```

Build both Linux and AS400 fragments when both native artifacts are installed:

```bash
mvn -Prepository-all -DskipTests clean install
```

The Linux fragment is:

```text
com.sap.conn.jco.linux.x86_64/target/sapjco3-linux-x86_64-3.1.13.jar
```

Verify its native payload and manifest:

```bash
jar tf com.sap.conn.jco.linux.x86_64/target/sapjco3-linux-x86_64-3.1.13.jar \
  | grep 'libsapjco3.so'
unzip -p com.sap.conn.jco.linux.x86_64/target/sapjco3-linux-x86_64-3.1.13.jar \
  META-INF/MANIFEST.MF
```

The manifest must identify `com.sap.conn.jco.linux.x86_64` as a fragment of
`com.sap.conn.jco` version `3.1.13` and select Linux/x86-64 native code.

## Camel Main and Spring Boot

For a non-OSGi deployment, extract the SAP Linux package into a private
runtime directory and keep the SAP JARs external to the application archive:

```bash
export SAPJCO_HOME=/opt/camel-sap/sap
export LD_LIBRARY_PATH="${SAPJCO_HOME}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

java -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar:${SAPJCO_HOME}/sapidoc3.jar:/opt/camel-sap/app/lib/*:/opt/camel-sap/app/app.jar" \
  com.example.Application
```

Use these application dependencies:

```xml
<dependency>
  <groupId>io.github.chiragsanghavi.camel</groupId>
  <artifactId>camel-sap</artifactId>
  <version>4.10.2</version>
</dependency>
<dependency>
  <groupId>com.sap.conn.jco</groupId>
  <artifactId>sapjco3</artifactId>
  <version>3.1.13</version>
  <scope>provided</scope>
</dependency>
<dependency>
  <groupId>com.sap.conn.idoc</groupId>
  <artifactId>sapidoc3</artifactId>
  <version>3.1.4</version>
  <scope>provided</scope>
</dependency>
```

Use the Apache Camel `4.10.2` BOM for Camel dependencies. Do not package SAP
JCo inside a Spring Boot fat JAR; use an external classpath or loader path.

The connection model and route URIs are the same as AS400. Follow
[`../com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md`](../com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md),
substituting Linux environment paths and neutral destination/server names as
needed.

## OSGi deployment

Install these bundles:

```text
sapjco3-linux-x86_64-3.1.13.jar
sapjco3-osgi-3.1.13.jar
sapidoc3-osgi-3.1.4.jar
camel-sap-model-4.10.2.jar
camel-sap-model-edit-4.10.2.jar
camel-sap-runtime-4.10.2.jar
camel-sap-4.10.2.jar
```

Install the native fragment before resolving the `com.sap.conn.jco` host.
Fragments cannot be started independently. Verify that the fragment attaches
to the host and that no `UnsatisfiedLinkError` occurs.

## Smoke test

Verify native loading before connecting to SAP:

```bash
java -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar" com.sap.conn.jco.About
```

Then validate one outbound and one inbound IDoc against a non-production SAP
system, as described in the AS400 configuration guide.
