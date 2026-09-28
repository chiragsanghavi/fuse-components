# Camel SAP 4.10.2 on IBM i / AS400 PASE

For the shared Linux/AS400 workflow and side-by-side OS callouts, start with
[`../INSTALL-LINUX-AS400.md`](../INSTALL-LINUX-AS400.md).

After installing the component, follow
[`CONFIGURATION-AS400-PASE.md`](CONFIGURATION-AS400-PASE.md) to configure SAP
destinations, an inbound IDoc server, and Camel routes.

This guide installs the community-aligned Camel SAP component from the
`camel-4.10.2-branch-iseries` branch. It uses:

- Apache Camel `4.10.2`
- SAP Java Connector (JCo) `3.1.13`
- SAP Java IDoc Library `3.1.4`
- 64-bit IBM i / OS400 PASE native libraries

SAP JCo and SAP IDoc are licensed SAP software. Obtain them from SAP and do not
commit or redistribute the ZIP, JAR, TAR, or native library files.

## Prerequisites

Build machine:

- JDK 17
- Maven 3.8 or newer
- `bash`, `jar`, and `tar`
- Access to Maven Central

IBM i runtime:

- A 64-bit Java runtime supported by SAP JCo 3.1
- PASE shell access (SSH or QP2TERM)
- SAP network connectivity and the required SAP gateway configuration
- The IBM i environment settings required by SAP Note `1269638`

Confirm the IBM i JVM architecture before deployment:

```bash
java -XshowSettings:properties -version 2>&1 | grep -E 'os.name|os.arch|java.version'
```

Expected values include `os.name = OS/400` and `os.arch = ppc64`.

## Obtain the SAP archives

Place these files in the project-local `reference/` directory:

```text
reference/sapjco31P_13-70004561.zip
reference/sapjidoc31P_4-80004914.zip
```

The directory is ignored by Git. The JCo ZIP must contain
`sapjco3-as400_pase_64-3.1.13.tar`.

## Install SAP artifacts into Maven

From the `camel-sap` directory, run:

```bash
./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh
```

To use a non-default local Maven repository:

```bash
MAVEN_REPO_LOCAL=/path/to/maven/repository \
  ./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh
```

The script installs these local-only Maven artifacts:

```text
com.sap.conn.jco:sapjco3:jar:3.1.13
com.sap.conn.idoc:sapidoc3:jar:3.1.4
com.sap.conn.jco:sapjco3:so:as400-pase_64:3.1.13
com.sap.conn.jco:sapjco3-native:tar:as400-pase_64:3.1.13
```

## Build Camel SAP

Build the component and the IBM i OSGi fragment without executing tests:

```bash
mvn -Prepository-as400 -DskipTests clean install
```

For a custom Maven repository, use the same path used by the installer:

```bash
mvn -Dmaven.repo.local=/path/to/maven/repository \
  -Prepository-as400 -DskipTests clean install
```

The legacy `repository` profile remains an alias for `repository-as400`.
When the Linux native artifact is also installed, build both supported native
fragments with `mvn -Prepository-all -DskipTests clean install`.

Important outputs:

```text
camel-sap-component/target/camel-sap-4.10.2.jar
com.sap.conn.jco/target/sapjco3-osgi-3.1.13.jar
com.sap.conn.idoc/target/sapidoc3-osgi-3.1.4.jar
com.sap.conn.jco.os400.ppc64/target/sapjco3-os400-ppc64-3.1.13.jar
```

Verify the native fragment before transfer:

```bash
jar tf com.sap.conn.jco.os400.ppc64/target/sapjco3-os400-ppc64-3.1.13.jar \
  | grep '\.so$'
```

It must contain:

```text
libsapjco3.so
os4apilib.so
libicudata57.so
libicui18n57.so
libicuuc57.so
libpathextension.so
```

## Camel Main or Spring Boot deployment

For a non-OSGi application, keep SAP JCo outside a Spring Boot fat JAR. SAP
requires one JCo installation per JVM/classloader and warns against embedding
JCo in application deployment archives.

On IBM i, create a private SAP JCo installation directory and extract the SAP
tar there:

```bash
mkdir -p /opt/camel-sap/sap
cd /opt/camel-sap/sap
tar -xvf sapjco3-as400_pase_64-3.1.13.tar
```

Place `sapidoc3.jar` from the SAP IDoc ZIP in the same directory.

Set the runtime environment before starting Java:

```bash
export SAPJCO_HOME=/opt/camel-sap/sap
export LIBPATH="${SAPJCO_HOME}${LIBPATH:+:${LIBPATH}}"
```

Also apply the JVM-specific IBM i variables required by SAP Note `1269638`.

Add the Camel component to the application POM:

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

Use the Apache Camel `4.10.2` BOM for the rest of the Camel dependencies.
The component and its published POMs have no Fuse parent or Fuse repository
dependency. The SAP artifacts remain local because SAP does not publish them
to Maven Central.
Do not package `sapjco3.jar` or `sapidoc3.jar` inside the application JAR.
Add the exact SAP-provided filenames to the external runtime classpath:

```bash
java \
  -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar:${SAPJCO_HOME}/sapidoc3.jar:/opt/camel-sap/app/lib/*:/opt/camel-sap/app/app.jar" \
  com.example.Application
```

For Spring Boot, use an exploded/thin deployment or `PropertiesLauncher` with
an external loader path. Do not use a conventional executable fat JAR that
nests the SAP JARs.

## OSGi deployment

Transfer these bundles to IBM i:

```text
sapjco3-osgi-3.1.13.jar
sapidoc3-osgi-3.1.4.jar
sapjco3-os400-ppc64-3.1.13.jar
camel-sap-model-4.10.2.jar
camel-sap-model-edit-4.10.2.jar
camel-sap-runtime-4.10.2.jar
camel-sap-4.10.2.jar
```

The OS400 bundle is a fragment of `com.sap.conn.jco`. Install the fragment
before resolving or starting the JCo host bundle. A generic OSGi sequence is:

```text
install sapjco3-os400-ppc64-3.1.13.jar
install sapjco3-osgi-3.1.13.jar
install sapidoc3-osgi-3.1.4.jar
install the Camel SAP model/runtime/component bundles
resolve the JCo host and fragment
start the JCo host, IDoc bundle, and Camel SAP bundles
```

Exact commands depend on the OSGi framework. In Apache Karaf, use
`bundle:install`, `bundle:resolve`, `bundle:start`, and `bundle:list`.
Fragments cannot be started independently.

After installation, verify:

- The `com.sap.conn.jco.os400.ppc64` fragment is attached to the
  `com.sap.conn.jco` host bundle.
- The JCo and IDoc bundles are resolved or active.
- No `UnsatisfiedLinkError` or `ClassNotFoundException` appears.
- All six native libraries are available in the framework bundle cache.

If IBM i does not load the five dependent libraries from the OSGi bundle cache,
extract the SAP native tar into a fixed runtime directory and add that directory
to `LIBPATH` before starting the OSGi JVM.

## Smoke tests

First test native loading without connecting to SAP:

```bash
java \
  -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar" \
  com.sap.conn.jco.About
```

Then start the Camel application and verify that all configured SAP endpoints
are created. Finally test both directions using a non-production SAP system:

1. Send one IDoc through `sap-idoc-destination` or
   `sap-idoclist-destination`.
2. Receive one IDoc through `sap-idoclist-server`.
3. Confirm the SAP transaction ID and IDoc status in both Camel logs and SAP.

## Troubleshooting

`UnsatisfiedLinkError: no sapjco3 in java.library.path`:

- Confirm `libsapjco3.so` exists in `SAPJCO_HOME`.
- Confirm `LIBPATH` and `java.library.path` include that directory.
- Confirm the JVM is 64-bit and reports `ppc64`.

Dependent library load failure:

- Keep all six SAP `.so` files in the same directory.
- Confirm `LIBPATH` includes that directory before the JVM starts.
- Apply the settings from SAP Note `1269638` for the installed JVM.

`ClassNotFoundException` for `com.sap.conn.jco` or `com.sap.conn.idoc`:

- For Camel Main/Spring Boot, add the external SAP JARs to the JVM classpath.
- For OSGi, verify the JCo and IDoc host bundles contain `sapjco3.jar` and
  `sapidoc3.jar` respectively and are resolved.

Native library already loaded in another classloader:

- Remove duplicate SAP JARs from application or framework bundles.
- Ensure there is only one JCo host installation in the JVM.

## Production readiness

Before production use, complete an IBM i runtime test covering bundle
resolution, native loading, RFC connectivity, outbound IDoc delivery, inbound
IDoc reception, restart recovery, and duplicate/TID handling. A successful
cross-platform Maven build does not replace this PASE validation.
