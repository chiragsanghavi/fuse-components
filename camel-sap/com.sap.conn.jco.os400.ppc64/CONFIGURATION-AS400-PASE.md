# Configure Camel SAP 4.10.2 on IBM i / AS400 PASE

This guide configures the Camel SAP component after completing
[`INSTALL-AS400-PASE.md`](INSTALL-AS400-PASE.md). The SAP connection model is
the same on PASE as on other platforms. PASE additionally needs the native
library environment described in the installation guide.

## Configuration model

The component does not create SAP connections from endpoint query parameters.
It requires a `SapConnectionConfiguration` containing named entries:

- A **destination** is an authenticated outbound connection to an SAP ABAP
  system. It is also used by an inbound server to retrieve IDoc metadata.
- A **server** is a JCo program registered with an SAP gateway for inbound RFC
  or IDoc traffic.
- The first endpoint path value selects one of those names. For example,
  `sap-idoc-destination:as400Dest:ORDERS05` selects destination `as400Dest`,
  while `sap-idoclist-server:as400Server:ORDERS05` selects server
  `as400Server`.

At least one destination is required for sending. Receiving requires both a
server and the destination named by its `repositoryDestination` property.

## Runtime environment on PASE

Set the native library paths before starting the JVM:

```bash
export SAPJCO_HOME=/opt/camel-sap/sap
export LIBPATH="${SAPJCO_HOME}${LIBPATH:+:${LIBPATH}}"
export JAVA_TOOL_OPTIONS="-Djava.library.path=${SAPJCO_HOME}"
```

Keep these files together in `SAPJCO_HOME`:

```text
sapjco3.jar
sapidoc3.jar
libsapjco3.so
os4apilib.so
libicudata57.so
libicui18n57.so
libicuuc57.so
libpathextension.so
```

Apply the IBM i JVM settings required by SAP Note `1269638`. Confirm native
loading independently before diagnosing Camel configuration:

```bash
java -Djava.library.path="${SAPJCO_HOME}" \
  -cp "${SAPJCO_HOME}/sapjco3.jar" com.sap.conn.jco.About
```

## Connection properties

Use environment variables or a secrets manager for credentials. A suitable
`application.properties` file is:

```properties
# Outbound SAP application-server connection
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
sap.server.progid=CAMEL_IDOC_AS400
sap.server.connection-count=2
```

The minimum direct application-server destination fields are `ashost`,
`sysnr`, `client`, `user`, and `passwd`. `lang`, `poolCapacity`, and
`peakLimit` are common optional settings.

For SAP message-server load balancing, use `mshost`, `r3name`, and `group`
instead of `ashost` and `sysnr`. SAProuter and SNC installations can also set
the corresponding `saprouter`, `sncMode`, `sncLibrary`, `sncMyname`,
`sncPartnername`, and `sncQop` properties.

The minimum server fields are `gwhost`, `gwserv`, `progid`,
`repositoryDestination`, and `connectionCount`. The program ID is
case-sensitive and must exactly match the SAP gateway registration.

## `camel.component.*` properties

Camel's generated component metadata supports the ordinary options of each
actual endpoint scheme. For example:

```properties
camel.component.sap-idoc-destination.lazy-start-producer=true
camel.component.sap-idoclist-server.bridge-error-handler=true
```

There is no component whose scheme is simply `sap`, so
`camel.component.sap.*` is not a valid namespace in this version. More
importantly, the named destination and server maps are not currently exposed
as generated Camel component properties. Configure those maps with one of the
Spring XML, Spring Boot Java, or Camel Main approaches below.

A future runtime-neutral configuration layer should use one shared property
tree for all SAP schemes, rather than duplicate credentials under every
`camel.component.sap-*-destination.*` namespace. Until that layer is
implemented and tested, properties such as
`camel.component.sap.destinations.as400.ashost` must not be assumed to work.

## Spring XML configuration

Load this file as a Spring application context. Spring Boot applications can
import it with `@ImportResource("classpath:sap-application-context.xml")`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
                           https://www.springframework.org/schema/beans/spring-beans.xsd">

  <bean id="as400Destination"
        class="org.fusesource.camel.component.sap.model.rfc.impl.DestinationDataImpl">
    <property name="ashost" value="${sap.client.ashost}"/>
    <property name="sysnr" value="${sap.client.sysnr}"/>
    <property name="client" value="${sap.client.client}"/>
    <property name="user" value="${sap.client.user}"/>
    <property name="passwd" value="${sap.client.passwd}"/>
    <property name="lang" value="${sap.client.lang}"/>
    <property name="poolCapacity" value="${sap.client.pool-capacity}"/>
    <property name="peakLimit" value="${sap.client.peak-limit}"/>
  </bean>

  <bean id="as400Server"
        class="org.fusesource.camel.component.sap.model.rfc.impl.ServerDataImpl">
    <property name="gwhost" value="${sap.server.gwhost}"/>
    <property name="gwserv" value="${sap.server.gwserv}"/>
    <property name="progid" value="${sap.server.progid}"/>
    <property name="repositoryDestination" value="as400Dest"/>
    <property name="connectionCount" value="${sap.server.connection-count}"/>
  </bean>

  <bean id="sap-configuration"
        class="org.fusesource.camel.component.sap.SapConnectionConfiguration">
    <property name="destinationDataStore">
      <map>
        <entry key="as400Dest" value-ref="as400Destination"/>
      </map>
    </property>
    <property name="serverDataStore">
      <map>
        <entry key="as400Server" value-ref="as400Server"/>
      </map>
    </property>
  </bean>
</beans>
```

The bean ID `as400Server` and the server map key may be identical; they serve
different purposes. Endpoint URIs use the map key, not the Spring bean ID.

## Spring Boot Java configuration

Java configuration avoids placing passwords directly in source files and can
be shared by Java, XML, and YAML routes:

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
        server.setRepositoryDestination("as400Dest");
        server.setConnectionCount(env.getProperty("sap.server.connection-count", "2"));

        SapConnectionConfiguration configuration = new SapConnectionConfiguration();
        configuration.setDestinationDataStore(Map.of("as400Dest", destination));
        configuration.setServerDataStore(Map.of("as400Server", server));
        return configuration;
    }
}
```

`SapConnectionConfiguration` registers its stores with the component's JCo
providers when it is constructed. Ensure this bean is created before Camel
starts its routes; normal non-lazy Spring Boot bean initialization does that.

## Camel Main configuration

Camel Main can create the same configuration before running the application:

```java
DestinationData destination = new DestinationDataImpl();
destination.setAshost(System.getenv("SAP_ASHOST"));
destination.setSysnr(System.getenv().getOrDefault("SAP_SYSNR", "00"));
destination.setClient(System.getenv().getOrDefault("SAP_CLIENT", "100"));
destination.setUser(System.getenv("SAP_USER"));
destination.setPasswd(System.getenv("SAP_PASSWORD"));
destination.setLang("EN");

ServerData server = new ServerDataImpl();
server.setGwhost(System.getenv("SAP_GWHOST"));
server.setGwserv(System.getenv().getOrDefault("SAP_GWSERV", "sapgw00"));
server.setProgid(System.getenv("SAP_PROGID"));
server.setRepositoryDestination("as400Dest");
server.setConnectionCount("2");

SapConnectionConfiguration sap = new SapConnectionConfiguration();
sap.setDestinationDataStore(Map.of("as400Dest", destination));
sap.setServerDataStore(Map.of("as400Server", server));

Main main = new Main();
main.bind("sap-configuration", sap);
main.configure().addRoutesBuilder(new IdocRoutes());
main.run(args);
```

Binding `sap` gives the configuration the same lifecycle as the Main registry.
Imports are the same as the Spring example, plus
`org.apache.camel.main.Main` and the route builder class.

## IDoc endpoint URIs

Send one IDoc document transactionally:

```text
sap-idoc-destination:as400Dest:ORDERS05
```

Send an IDoc list transactionally:

```text
sap-idoclist-destination:as400Dest:ORDERS05
```

Receive transactional IDoc lists:

```text
sap-idoclist-server:as400Server:ORDERS05
```

The complete IDoc URI form is:

```text
scheme:destination-or-server:idocType:idocTypeExtension:systemRelease:applicationRelease
```

Trailing metadata values are optional. Preserve empty positions when a later
value is supplied. The IDoc type must match the partner profile configured in
SAP.

Queued outbound forms add the queue after the destination:

```text
sap-qidoc-destination:as400Dest:QUEUE_NAME:ORDERS05
sap-qidoclist-destination:as400Dest:QUEUE_NAME:ORDERS05
```

## Java route

```java
public final class IdocRoutes extends RouteBuilder {
    @Override
    public void configure() {
        from("direct:send-idoc")
            .routeId("send-idoc-to-sap")
            .to("sap-idoc-destination:as400Dest:ORDERS05");

        from("sap-idoclist-server:as400Server:ORDERS05"
             + "?propagateExceptions=true")
            .routeId("receive-idoc-from-sap")
            .to("bean:idocHandler");
    }
}
```

The outbound message body must be the component model's
`org.fusesource.camel.component.sap.model.idoc.Document`; the list endpoint
uses `DocumentList`. For outbound traffic, obtain a correctly structured
document from the destination endpoint so metadata and segment definitions are
loaded from SAP:

```java
SapTransactionalIDocDestinationEndpoint endpoint =
    camelContext.getEndpoint(
        "sap-idoc-destination:as400Dest:ORDERS05",
        SapTransactionalIDocDestinationEndpoint.class);
Document document = endpoint.createDocument();
document.setMessageType("ORDERS");
// Set control-record partner fields and populate document.getRootSegment().
producerTemplate.sendBody("direct:send-idoc", document);
```

## YAML route

Use the Spring Boot Java bean above for connection configuration, then place
this route in a Camel YAML route file:

```yaml
- route:
    id: send-idoc-to-sap
    from:
      uri: direct:send-idoc
      steps:
        - to:
            uri: sap-idoc-destination:as400Dest:ORDERS05

- route:
    id: receive-idoc-from-sap
    from:
      uri: sap-idoclist-server:as400Server:ORDERS05
      parameters:
        propagateExceptions: true
      steps:
        - to:
            uri: bean:idocHandler
```

YAML defines the routes only in this example. The Java configuration is still
required because destinations and servers are typed model objects rather than
flat Camel component properties.

## XML route

Import the Spring XML connection configuration above and define routes in the
Camel XML DSL:

```xml
<camelContext xmlns="http://camel.apache.org/schema/spring">
  <route id="send-idoc-to-sap">
    <from uri="direct:send-idoc"/>
    <to uri="sap-idoc-destination:as400Dest:ORDERS05"/>
  </route>

  <route id="receive-idoc-from-sap">
    <from uri="sap-idoclist-server:as400Server:ORDERS05?propagateExceptions=true"/>
    <to uri="bean:idocHandler"/>
  </route>
</camelContext>
```

Escape query-string ampersands as `&amp;` when adding multiple XML endpoint
options.

## SAP-side setup for inbound IDocs

Coordinate these SAP settings with the SAP Basis team:

1. Create an SM59 TCP/IP destination using **Registered Server Program**.
2. Set its program ID to the exact value of `sap.server.progid`, for example
   `CAMEL_IDOC_AS400`.
3. Use the gateway host and service represented by `gwhost` and `gwserv`.
4. Create the required IDoc port and partner profile (commonly WE21 and WE20)
   for the selected message and basic IDoc types.
5. Permit the IBM i host through SAP gateway security (`reginfo`/`secinfo`)
   and network firewalls.
6. Start Camel, then test the SM59 destination. A registered program is not
   visible until the Camel consumer has started successfully.

Outbound IDocs require the SAP user to have RFC and IDoc authorizations and
the target system to have the corresponding partner/profile configuration.

## Validation checklist

1. Run `com.sap.conn.jco.About` successfully under the same PASE environment
   used by Camel.
2. Start Camel without `JCoException`, `UnsatisfiedLinkError`, or unknown
   destination/server errors.
3. Confirm the registered program appears in SAP gateway monitor SMGW.
4. Test the SM59 registered-server destination.
5. Send one outbound IDoc and verify its SAP status in WE02 or WE05.
6. Send one inbound IDoc from SAP and verify Camel receives a `DocumentList`.
7. Restart Camel and repeat both directions to test gateway re-registration.

Do not enable JCo trace permanently in production because traces can contain
sensitive connection and business data.

## Common errors

`Destination as400Dest does not exist`:

- Ensure `SapConnectionConfiguration` is instantiated before routes start.
- Ensure the destination map key exactly matches the endpoint URI.

`Server as400Server does not exist`:

- Ensure the server map key exactly matches the inbound endpoint URI.
- Ensure the route uses `sap-idoclist-server`, not a destination scheme.

`JCO_ERROR_COMMUNICATION`:

- Check DNS, route, firewall, `ashost`, `sysnr`, and SAProuter settings.
- SAP system number `00` normally maps to dispatcher port `3200`, but use the
  actual landscape configuration.

Registered program not found or registration denied:

- Match `progid`, `gwhost`, and `gwserv` with SM59 exactly.
- Check SAP gateway `reginfo`/`secinfo`, SMGW logs, and firewall rules.

IDoc metadata or segment lookup failure:

- Verify `repositoryDestination` names a working destination.
- Verify the basic IDoc type exists in that SAP system and client.
- Add release/extension URI fields if metadata selection requires them.

Authentication failure:

- Check client, user, password, language, and user lock/expiration state.
- Confirm the technical user has the required RFC and IDoc authorizations.
