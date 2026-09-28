# Install Camel SAP 4.10.2 on Linux and IBM i / AS400

This is the shared installation and deployment guide for the community Camel
SAP component on its two supported native platforms:

| Platform | Architecture | SAP JCo native format | Maven build profile |
| --- | --- | --- | --- |
| Linux | x86_64/amd64 | ELF `libsapjco3.so` | `repository-linux` |
| IBM i / AS400 PASE | ppc64 | XCOFF `libsapjco3.so` plus five dependencies | `repository-as400` |

Both platforms use:

- Apache Camel `4.10.2`
- SAP Java Connector `3.1.13`
- SAP Java IDoc Library `3.1.4`
- community artifact `io.github.chiragsanghavi.camel:camel-sap:4.10.2`

SAP JCo and SAP IDoc are licensed SAP software. Obtain them from SAP. Do not
commit or redistribute SAP ZIPs, TARs, JARs, or native libraries.

Detailed platform references:

- [Linux x86_64 runbook](com.sap.conn.jco.linux.x86_64/INSTALL-LINUX-X86_64.md)
- [IBM i / AS400 PASE runbook](com.sap.conn.jco.os400.ppc64/INSTALL-AS400-PASE.md)
- [Connection and route configuration](com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md)

Although the configuration document has AS400 in its filename, its Java,
Spring, XML, YAML, destination, server, and endpoint configuration is shared.
Only the native-library environment differs by operating system.

## 1. Verify the target platform

Run:

```bash
uname -a
java -XshowSettings:properties -version 2>&1 \
  | grep -E 'os.name|os.arch|java.version'
```

> **Linux-specific:** `uname -m` must report `x86_64` (or equivalent amd64)
> and Java must be a 64-bit x86 JVM. ARM64 and 32-bit Linux are not supported
> by the current native wrapper.

> **IBM i / AS400-specific:** Java must run under PASE and report OS/400 with
> a 64-bit Power architecture such as `ppc64`. Apply the IBM i JVM environment
> required by SAP Note `1269638`.

Use a SAP-supported JDK and operating-system release for JCo 3.1.13. JDK 17 is
used to build this fork; SAP's support matrix remains authoritative for the
production runtime.

## 2. Obtain SAP packages

The project-local `reference/` directory is ignored by Git. The IDoc package
is required on both platforms:

```text
reference/sapjidoc31P_4-80004914.zip
```

> **Linux-specific:** Download SAP JCo `3.1.13` for Linux x86_64. The installer
> accepts SAP's Linux ZIP, its extracted TGZ/TAR, or an extracted
> `libsapjco3.so`. If only a raw `.so` is supplied, also place the matching
> `sapjco3.jar` in `reference/`.

> **IBM i / AS400-specific:** Place the following package in `reference/`:
>
> ```text
> reference/sapjco31P_13-70004561.zip
> ```
>
> It must contain `sapjco3-as400_pase_64-3.1.13.tar`.

For a combined build, provide both native packages. The Java JCo archive must
remain at version `3.1.13`; do not mix the JAR from one JCo version with a
native library from another.

Record checksums outside Git for deployment traceability:

```bash
sha256sum reference/sapjidoc31P_4-80004914.zip
sha256sum /secure/downloads/SAP-JCo-linux-x86_64.zip
sha256sum reference/sapjco31P_13-70004561.zip
```

## 3. Install licensed artifacts locally

The installer places SAP artifacts in a local Maven repository without
publishing them:

```bash
./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh \
  reference [optional-linux-jco-package]
```

Use one of these platform forms.

> **Linux-specific:** The AS400 ZIP is optional.
>
> ```bash
> ./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh \
>   reference /secure/downloads/SAP-JCo-linux-x86_64.zip
> ```

> **IBM i / AS400-specific:** No second argument is required.
>
> ```bash
> ./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh reference
> ```

> **Combined Linux and AS400:** Keep the AS400 ZIP under `reference/` and pass
> the Linux package as argument 2.

For an isolated or CI Maven repository:

```bash
MAVEN_REPO_LOCAL=/path/to/repository \
  ./com.sap.conn.jco.os400.ppc64/install-sap-artifacts.sh \
  reference /secure/downloads/SAP-JCo-linux-x86_64.zip
```

Common artifacts:

```text
com.sap.conn.jco:sapjco3:jar:3.1.13
com.sap.conn.idoc:sapidoc3:jar:3.1.4
```

> **Linux-specific artifact:**
> `com.sap.conn.jco:sapjco3:so:linux-x86_64:3.1.13`.

> **IBM i / AS400-specific artifacts:**
> `com.sap.conn.jco:sapjco3:so:as400-pase_64:3.1.13` and
> `com.sap.conn.jco:sapjco3-native:tar:as400-pase_64:3.1.13`.

The installer rejects an AS400 XCOFF library when supplied as a Linux native
library.

## 4. Build the component

Run the profile matching the target:

> **Linux-specific:**
>
> ```bash
> mvn -Prepository-linux -DskipTests clean install
> ```

> **IBM i / AS400-specific:**
>
> ```bash
> mvn -Prepository-as400 -DskipTests clean install
> ```
>
> `repository` remains an alias for `repository-as400`.

> **Combined build:**
>
> ```bash
> mvn -Prepository-all -DskipTests clean install
> ```

Use the same `-Dmaven.repo.local=/path/to/repository` value used by the
installer when building against an isolated repository.

Common outputs:

```text
camel-sap-component/target/camel-sap-4.10.2.jar
com.sap.conn.jco/target/sapjco3-osgi-3.1.13.jar
com.sap.conn.idoc/target/sapidoc3-osgi-3.1.4.jar
org.fusesource.camel.component.sap.model/target/camel-sap-model-4.10.2.jar
org.fusesource.camel.component.sap.model.edit/target/camel-sap-model-edit-4.10.2.jar
org.fusesource.camel.component.sap/target/camel-sap-runtime-4.10.2.jar
```

> **Linux-specific output:**
> `com.sap.conn.jco.linux.x86_64/target/sapjco3-linux-x86_64-3.1.13.jar`.

> **IBM i / AS400-specific output:**
> `com.sap.conn.jco.os400.ppc64/target/sapjco3-os400-ppc64-3.1.13.jar`.

## 5. Add the component to an application

Import the standard Apache Camel BOM and add the community component. No Fuse
or Red Hat artifact is required:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.apache.camel</groupId>
      <artifactId>camel-bom</artifactId>
      <version>4.10.2</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
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
</dependencies>
```

Keep `sapjco3.jar`, `sapidoc3.jar`, and native libraries outside an executable
or fat application JAR. SAP JCo expects one installation per JVM/classloader.

## 6. Configure destinations and servers

The component requires a `SapConnectionConfiguration` with named maps:

- `linuxDest` or `as400Dest`: outbound authenticated SAP destination
- `linuxServer` or `as400Server`: inbound JCo registered server
- `repositoryDestination`: destination used by the server for IDoc metadata

The model is OS-neutral. Example endpoint URIs are:

```text
sap-idoc-destination:platformDest:ORDERS05
sap-idoclist-destination:platformDest:ORDERS05
sap-idoclist-server:platformServer:ORDERS05
```

Replace `platformDest` and `platformServer` with the exact keys configured in
the destination/server maps. See the shared
[configuration guide](com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md)
for Spring Java, Spring XML, Camel Main, Java DSL, YAML, and XML examples.

The `org.fusesource.camel.*` Java package names in those examples are retained
API namespaces. They do not require a Fuse runtime.

## 7. Configure native loading

Create a private runtime directory containing exact SAP-provided filenames:

```text
sapjco3.jar
sapidoc3.jar
libsapjco3.so
```

> **Linux-specific:** Set both paths before starting Java:
>
> ```bash
> export SAPJCO_HOME=/opt/camel-sap/sap
> export LD_LIBRARY_PATH="${SAPJCO_HOME}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
> java -Djava.library.path="${SAPJCO_HOME}" ...
> ```
>
> Run `ldd ${SAPJCO_HOME}/libsapjco3.so` and resolve every `not found`
> dependency. Check SELinux and `noexec` mounts if loading is still denied.

> **IBM i / AS400-specific:** Keep all six native libraries together:
>
> ```text
> libsapjco3.so
> os4apilib.so
> libicudata57.so
> libicui18n57.so
> libicuuc57.so
> libpathextension.so
> ```
>
> ```bash
> export SAPJCO_HOME=/opt/camel-sap/sap
> export LIBPATH="${SAPJCO_HOME}${LIBPATH:+:${LIBPATH}}"
> java -Djava.library.path="${SAPJCO_HOME}" ...
> ```
>
> Also apply SAP Note `1269638` settings for the selected IBM i JVM.

Test JCo independently before starting Camel:

```bash
java -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar" com.sap.conn.jco.About
```

## 8. Configure SAP for inbound IDocs

Coordinate with the SAP Basis team:

1. Create an SM59 TCP/IP destination using **Registered Server Program**.
2. Match its program ID exactly to the configured `progid`.
3. Match `gwhost` and `gwserv` to the SAP gateway.
4. Configure the IDoc port and partner profile, commonly WE21 and WE20.
5. Permit registration in gateway `reginfo`/`secinfo` and firewalls.
6. Start the Camel consumer before running the SM59 connection test.

> **Linux-specific:** The JCo server normally opens an outbound registration
> connection from Linux to the SAP gateway. Verify DNS, routing, SELinux, and
> the outbound gateway port (commonly `33NN`, subject to the landscape).

> **IBM i / AS400-specific:** Verify PASE DNS/routing independently of the
> native IBM i environment and ensure IBM i firewall rules permit the gateway
> connection.

## 9. OSGi deployment

Install the platform native fragment before resolving the JCo host bundle:

```text
platform-native-fragment
sapjco3-osgi-3.1.13.jar
sapidoc3-osgi-3.1.4.jar
camel-sap-model-4.10.2.jar
camel-sap-model-edit-4.10.2.jar
camel-sap-runtime-4.10.2.jar
camel-sap-4.10.2.jar
```

> **Linux-specific fragment:** `sapjco3-linux-x86_64-3.1.13.jar`, symbolic
> name `com.sap.conn.jco.linux.x86_64`.

> **IBM i / AS400-specific fragment:** `sapjco3-os400-ppc64-3.1.13.jar`,
> symbolic name `com.sap.conn.jco.os400.ppc64`.

Both fragments attach to host `com.sap.conn.jco` version `3.1.13`. Fragments
cannot be started independently. Resolve the host and fragment, then start the
host, IDoc, model, runtime, and component bundles.

## 10. Production validation

Validate each target independently:

1. JCo `About` runs under the service account and production environment.
2. Camel starts without `UnsatisfiedLinkError`, `JCoException`, or missing
   destination/server errors.
3. The registered program appears in SAP gateway monitor SMGW.
4. The SM59 registered-server connection test succeeds.
5. One outbound IDoc reaches the expected status in WE02/WE05.
6. One inbound IDoc reaches Camel as a `DocumentList`.
7. A process restart re-registers the server and both directions still work.
8. Credentials and business payloads are absent from normal logs.

> **Linux-specific gate:** `file libsapjco3.so` reports ELF 64-bit x86-64 and
> `ldd` reports no missing libraries.

> **IBM i / AS400-specific gate:** `file libsapjco3.so` reports 64-bit XCOFF,
> all six native files are present, and the PASE `LIBPATH` is effective.

Do not enable JCo tracing permanently in production because traces can contain
sensitive connection and business data.

## 11. Common failures

`UnsatisfiedLinkError`:

- Verify architecture and JCo version alignment.
- Verify the OS-specific library path from section 7.
- Test native loading outside Camel with `com.sap.conn.jco.About`.

Destination or server does not exist:

- Create `SapConnectionConfiguration` before routes start.
- Match destination/server map keys and endpoint URI names exactly.

`JCO_ERROR_COMMUNICATION`:

- Check DNS, routes, firewall, SAProuter, host, system number, and gateway
  service from the actual runtime environment.

Registered program not found or denied:

- Match `progid`, gateway host, and service with SM59.
- Inspect SAP gateway `reginfo`, `secinfo`, and SMGW logs.

IDoc metadata failure:

- Confirm `repositoryDestination` names a working destination.
- Confirm the IDoc basic type/extension exists in the target SAP client.

For platform-specific diagnostics, use the detailed Linux and AS400 runbooks
linked at the top of this guide.
