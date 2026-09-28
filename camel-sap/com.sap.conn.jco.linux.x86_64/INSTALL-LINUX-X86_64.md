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

This fork supports Linux on x86_64 only. It does not currently build a Linux
ARM64 or 32-bit x86 native fragment. A Linux container running on an ARM host
must therefore use an x86_64 image and runtime emulation, which is not a
recommended production arrangement.

Confirm the runtime architecture:

```bash
uname -m
java -XshowSettings:properties -version 2>&1 | grep -E 'os.name|os.arch|java.version'
```

`uname -m` and `os.arch` must identify x86_64/amd64. SAP JCo native libraries
must match the JVM architecture.

Check the system C library because SAP's Linux library is dynamically linked:

```bash
ldd --version | head -1
```

Use a SAP-supported JDK and Linux distribution for the selected JCo release.
The component build uses JDK 17, but SAP's support matrix remains authoritative
for the production JVM and operating system.

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

Inspect the downloaded package before installing it:

```bash
file /secure/downloads/libsapjco3.so
sha256sum /secure/downloads/SAP-JCo-linux-x86_64.zip
```

The native library must report `ELF 64-bit` and `x86-64`. Record SAP's original
filename and the SHA-256 digest in deployment records, but do not commit the
licensed archive or its extracted files.

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

The reactor installs the following community artifacts in the selected local
Maven repository:

```text
io.github.chiragsanghavi.camel:camel-sap:4.10.2
io.github.chiragsanghavi.camel:camel-sap-model:4.10.2
io.github.chiragsanghavi.camel:camel-sap-model-edit:4.10.2
io.github.chiragsanghavi.camel:camel-sap-runtime:4.10.2
io.github.chiragsanghavi.camel:sapjco3-osgi:3.1.13
io.github.chiragsanghavi.camel:sapidoc3-osgi:3.1.4
io.github.chiragsanghavi.camel:sapjco3-linux-x86_64:3.1.13
```

For CI or multiple developers, publish only the community-built artifacts to
a private Maven repository. Keep the SAP-provided JARs and native library in a
restricted repository whose access and redistribution terms comply with the
SAP license.

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

### Minimal Spring Boot POM

Import the standard Apache Camel BOM; no Fuse or Red Hat BOM is required:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.apache.camel.springboot</groupId>
      <artifactId>camel-spring-boot-bom</artifactId>
      <version>4.10.2</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>org.apache.camel.springboot</groupId>
    <artifactId>camel-spring-boot-starter</artifactId>
  </dependency>
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

This component does not provide a Spring Boot starter of its own. The regular
`camel-sap` artifact supplies Camel component metadata, while a Java or Spring
XML bean supplies the named SAP destinations and servers.

### Runtime filesystem

Use a dedicated non-root account and keep SAP software separate from the
application artifact:

```bash
sudo useradd --system --home /opt/camel-sap --shell /usr/sbin/nologin camel-sap
sudo install -d -o camel-sap -g camel-sap -m 0750 \
  /opt/camel-sap/app /opt/camel-sap/sap /etc/camel-sap
sudo install -o camel-sap -g camel-sap -m 0640 sapjco3.jar sapidoc3.jar \
  /opt/camel-sap/sap/
sudo install -o camel-sap -g camel-sap -m 0750 libsapjco3.so \
  /opt/camel-sap/sap/
```

Do not make SAP credentials readable by the application JAR's deployment
group. Use a root-managed environment file, systemd credentials, or a secrets
manager.

Check all native dependencies before starting Java:

```bash
file /opt/camel-sap/sap/libsapjco3.so
ldd /opt/camel-sap/sap/libsapjco3.so
```

Every `ldd` dependency must resolve. A `not found` result is an operating-system
library problem, not a Camel endpoint problem.

## Configure SAP connections

The component uses a `SapConnectionConfiguration` with named destination and
server maps. Endpoint URI parameters do not replace these typed objects.

Use external properties for connection details:

```properties
# Outbound SAP application-server destination
sap.client.ashost=sap.example.internal
sap.client.sysnr=00
sap.client.client=100
sap.client.user=CAMEL_IDOC
sap.client.passwd=${SAP_PASSWORD}
sap.client.lang=EN
sap.client.pool-capacity=2
sap.client.peak-limit=10

# Inbound registered JCo server
sap.server.gwhost=sap.example.internal
sap.server.gwserv=sapgw00
sap.server.progid=CAMEL_IDOC_LINUX
sap.server.connection-count=2
```

For SAP message-server load balancing, configure `mshost`, `r3name`, and
`group` instead of `ashost` and `sysnr`. Add SAProuter or SNC properties only
when required by the SAP landscape.

Create the typed configuration before Camel starts its routes:

```java
package com.example.sap;

import java.util.Map;

import org.fusesource.camel.component.sap.SapConnectionConfiguration;
import org.fusesource.camel.component.sap.model.rfc.DestinationData;
import org.fusesource.camel.component.sap.model.rfc.ServerData;
import org.fusesource.camel.component.sap.model.rfc.impl.DestinationDataImpl;
import org.fusesource.camel.component.sap.model.rfc.impl.ServerDataImpl;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

@Configuration
public class SapConfiguration {
    @Bean
    SapConnectionConfiguration sapConnectionConfiguration(Environment env) {
        DestinationData destination = new DestinationDataImpl();
        destination.setAshost(env.getRequiredProperty("sap.client.ashost"));
        destination.setSysnr(env.getRequiredProperty("sap.client.sysnr"));
        destination.setClient(env.getRequiredProperty("sap.client.client"));
        destination.setUser(env.getRequiredProperty("sap.client.user"));
        destination.setPasswd(env.getRequiredProperty("sap.client.passwd"));
        destination.setLang(env.getProperty("sap.client.lang", "EN"));
        destination.setPoolCapacity(env.getProperty("sap.client.pool-capacity", "2"));
        destination.setPeakLimit(env.getProperty("sap.client.peak-limit", "10"));

        ServerData server = new ServerDataImpl();
        server.setGwhost(env.getRequiredProperty("sap.server.gwhost"));
        server.setGwserv(env.getRequiredProperty("sap.server.gwserv"));
        server.setProgid(env.getRequiredProperty("sap.server.progid"));
        server.setRepositoryDestination("linuxDest");
        server.setConnectionCount(env.getProperty("sap.server.connection-count", "2"));

        SapConnectionConfiguration configuration = new SapConnectionConfiguration();
        configuration.setDestinationDataStore(Map.of("linuxDest", destination));
        configuration.setServerDataStore(Map.of("linuxServer", server));
        return configuration;
    }
}
```

The historical `org.fusesource.camel.*` Java package names are API namespaces;
they do not require a Fuse runtime or Fuse Maven artifacts.

Ordinary generated component options remain available, for example:

```properties
camel.component.sap-idoc-destination.lazy-start-producer=true
camel.component.sap-idoclist-server.bridge-error-handler=true
```

There is no `sap` component scheme, so `camel.component.sap.*` is not valid.
Destination/server maps must be configured with the typed bean shown above.

## Send and receive IDocs

A Java DSL route can send and receive IDocs directly:

```java
import org.apache.camel.builder.RouteBuilder;
import org.springframework.stereotype.Component;

@Component
public final class IdocRoutes extends RouteBuilder {
    @Override
    public void configure() {
        from("direct:send-idoc")
            .routeId("send-idoc-to-sap")
            .to("sap-idoc-destination:linuxDest:ORDERS05");

        from("sap-idoclist-server:linuxServer:ORDERS05"
             + "?propagateExceptions=true")
            .routeId("receive-idoc-from-sap")
            .to("bean:idocHandler");
    }
}
```

The outbound body for `sap-idoc-destination` is the component model's
`Document`; `sap-idoclist-destination` accepts `DocumentList`. Create outbound
documents from the destination endpoint so SAP metadata and segment definitions
are available:

```java
SapTransactionalIDocDestinationEndpoint endpoint =
    camelContext.getEndpoint(
        "sap-idoc-destination:linuxDest:ORDERS05",
        SapTransactionalIDocDestinationEndpoint.class);
Document document = endpoint.createDocument();
document.setMessageType("ORDERS");
// Set control-record partner fields and populate document.getRootSegment().
producerTemplate.sendBody("direct:send-idoc", document);
```

Equivalent YAML routes are:

```yaml
- route:
    id: send-idoc-to-sap
    from:
      uri: direct:send-idoc
      steps:
        - to:
            uri: sap-idoc-destination:linuxDest:ORDERS05

- route:
    id: receive-idoc-from-sap
    from:
      uri: sap-idoclist-server:linuxServer:ORDERS05
      parameters:
        propagateExceptions: true
      steps:
        - to:
            uri: bean:idocHandler
```

The complete IDoc URI form is:

```text
scheme:destination-or-server:idocType:idocTypeExtension:systemRelease:applicationRelease
```

Trailing fields are optional. Queued outbound variants use
`sap-qidoc-destination` or `sap-qidoclist-destination` and include the queue
name after the destination name.

## Configure SAP for inbound IDocs

Coordinate these steps with the SAP Basis team:

1. Create an SM59 TCP/IP destination using **Registered Server Program**.
2. Set its program ID to exactly `CAMEL_IDOC_LINUX` (or the configured value).
3. Match the gateway host/service to `gwhost` and `gwserv`.
4. Create the IDoc port and partner profile, commonly with WE21 and WE20.
5. Permit registration in gateway `reginfo`/`secinfo` and network policy.
6. Start the Camel consumer before testing SM59; the program is registered
   only while the JCo server is running.

The SAP technical user also needs the RFC and IDoc authorizations required by
the selected message types and metadata lookups.

## Spring Boot launch with external SAP JARs

Configure the Spring Boot Maven plugin with ZIP layout so its manifest uses
`PropertiesLauncher`:

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <layout>ZIP</layout>
  </configuration>
</plugin>
```

Start the application with the SAP directory as an external loader path:

```bash
export SAPJCO_HOME=/opt/camel-sap/sap
export LD_LIBRARY_PATH="${SAPJCO_HOME}"
export SAP_PASSWORD='use-a-secret-provider-in-production'

java \
  -Djava.library.path="${SAPJCO_HOME}" \
  -Dloader.path="${SAPJCO_HOME}" \
  -jar /opt/camel-sap/app/camel-sap-app.jar \
  --spring.config.additional-location=file:/etc/camel-sap/application.properties
```

Confirm the external files retain the exact SAP names `sapjco3.jar` and
`sapidoc3.jar`. Do not rename or unpack them into the application JAR.

## systemd service

Create `/etc/systemd/system/camel-sap.service`:

```ini
[Unit]
Description=Camel SAP IDoc service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=camel-sap
Group=camel-sap
EnvironmentFile=/etc/camel-sap/camel-sap.env
Environment=SAPJCO_HOME=/opt/camel-sap/sap
Environment=LD_LIBRARY_PATH=/opt/camel-sap/sap
ExecStart=/usr/bin/java -Djava.library.path=/opt/camel-sap/sap -Dloader.path=/opt/camel-sap/sap -jar /opt/camel-sap/app/camel-sap-app.jar --spring.config.additional-location=file:/etc/camel-sap/application.properties
Restart=on-failure
RestartSec=10
TimeoutStopSec=60
SuccessExitStatus=143
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Protect `/etc/camel-sap/camel-sap.env` with mode `0600`, then install and
start the service:

```bash
sudo chown root:root /etc/camel-sap/camel-sap.env
sudo chmod 0600 /etc/camel-sap/camel-sap.env
sudo systemctl daemon-reload
sudo systemctl enable --now camel-sap
sudo systemctl status camel-sap
sudo journalctl -u camel-sap -f
```

If systemd hardening is expanded, retest native loading and access to DNS,
configuration files, trust stores, SNC libraries, and temporary directories.

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
system.

## Production validation checklist

1. `file` reports an ELF 64-bit x86-64 `libsapjco3.so`.
2. `ldd` reports no missing native dependencies.
3. `com.sap.conn.jco.About` runs under the same account and environment as the
   service.
4. Camel starts without `UnsatisfiedLinkError`, `JCoException`, or unknown
   destination/server errors.
5. The registered program appears in SAP gateway monitor SMGW.
6. The SM59 registered-server connection test succeeds.
7. One outbound IDoc reaches the expected status in WE02/WE05.
8. One inbound IDoc reaches the Camel consumer as a `DocumentList`.
9. Restarting the service re-registers the program and both directions still
   work.
10. Logs and JCo traces do not expose passwords or business payloads.

Do not leave JCo tracing enabled in production; trace output can contain
sensitive connection and business data.

## Troubleshooting

`UnsatisfiedLinkError: no sapjco3 in java.library.path`:

- Confirm `/opt/camel-sap/sap/libsapjco3.so` exists and is executable/readable
  by the service account.
- Confirm both `LD_LIBRARY_PATH` and `-Djava.library.path` contain that exact
  directory.
- Confirm the JVM and native library are both x86-64.
- Check whether the filesystem is mounted `noexec` or blocked by SELinux.

`libsapjco3.so: cannot open shared object file` or an `ldd` dependency is
`not found`:

- Install the required operating-system runtime library from the Linux
  distribution.
- Do not fix this by copying unrelated `.so` files into `SAPJCO_HOME`.
- Re-run `ldd` as part of deployment validation.

`Destination linuxDest does not exist` or `Server linuxServer does not exist`:

- Ensure `SapConnectionConfiguration` is created before routes start.
- Match map keys and endpoint URI names exactly, including case.
- Use a destination endpoint for outbound traffic and
  `sap-idoclist-server` for inbound IDoc lists.

`JCO_ERROR_COMMUNICATION`:

- Check DNS, routing, firewalls, `ashost`, `sysnr`, and SAProuter settings.
- SAP system number `NN` commonly uses dispatcher port `32NN` and gateway
  port `33NN`, but use the ports defined by the actual landscape.

Registered program not found or registration denied:

- Match `progid`, `gwhost`, and `gwserv` with SM59 exactly.
- Inspect SAP gateway `reginfo`, `secinfo`, and SMGW logs.
- The registered-server connection is initiated from Linux to the SAP gateway;
  confirm the corresponding outbound network path.

IDoc metadata lookup fails:

- Confirm `repositoryDestination` names a working destination.
- Confirm the IDoc basic type and extension exist in the selected SAP client.
- Add release/extension URI fields when metadata selection requires them.

Authentication fails:

- Check SAP client, user, password, language, lock, and password-expiry state.
- Confirm the technical user has the required RFC and IDoc authorizations.

For the complete XML configuration variant and additional endpoint examples,
see
[`../com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md`](../com.sap.conn.jco.os400.ppc64/CONFIGURATION-AS400-PASE.md).
