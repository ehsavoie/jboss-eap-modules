@jboss-eap-6
Feature: Openshift EAP s2i tests
  # Always force IPv4 (CLOUD-188)
  # Append user-supplied arguments (CLOUD-412)
  # Allow the user to clear down the maven repository after running s2i (CLOUD-413)
  Scenario: Test to ensure that maven is run with -Djava.net.preferIPv4Stack=true and user-supplied arguments, even when MAVEN_ARGS is overridden, and doesn't clear the local repository after the build
    Given s2i build https://github.com/jboss-openshift/openshift-examples from helloworld
       | variable          | value                                                                                  |
       | MAVEN_ARGS        | -e -P jboss-eap-repository-insecure,-securecentral,insecurecentral -DskipTests package |
       | MAVEN_ARGS_APPEND | -Dfoo=bar                                                                              |
    Then s2i build log should contain -Djava.net.preferIPv4Stack=true
    Then s2i build log should contain -Dfoo=bar
    Then s2i build log should contain -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:+UseParallelOldGC -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=20 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90
    Then run sh -c 'test -d /tmp/artifacts/m2/org && echo all good' in container and immediately check its output for all good

  # CLOUD-458
  Scenario: Test s2i build with environment only
    Given s2i build https://github.com/jboss-openshift/openshift-examples from environment-only
    Then run sh -c 'echo FOO is $FOO' in container and check its output for FOO is Iedieve8
    And s2i build log should not contain cp: cannot stat '/tmp/src/*': No such file or directory

  # CLOUD-579
  Scenario: Test that maven is executed in batch mode
    Given s2i build https://github.com/jboss-openshift/openshift-examples from helloworld
    Then s2i build log should contain --batch-mode
    And s2i build log should not contain \r

  # CLOUD-807
  Scenario: Test if the container have the JavaScript engine available
    Given s2i build https://github.com/jboss-openshift/openshift-examples from eap-tests/jsengine
    Then container log should contain Engine found: jdk.nashorn.api.scripting.NashornScriptEngine
    And container log should contain Engine class provider found.
    And container log should not contain JavaScript engine not found.

  # Always force IPv4 (CLOUD-188)
  # Append user-supplied arguments (CLOUD-412)
  # Allow the user to clear down the maven repository after running s2i (CLOUD-413)
  Scenario: Test to ensure that maven is run with -Djava.net.preferIPv4Stack=true and user-supplied arguments, and clears the local repository after the build
    Given s2i build https://github.com/jboss-openshift/openshift-examples from helloworld
       | variable          | value                      |
       | MAVEN_ARGS_APPEND | -Dfoo=bar                  |
       | MAVEN_LOCAL_REPO  | /home/jboss/.m2/repository |
       | MAVEN_CLEAR_REPO  | true                       |
    Then s2i build log should contain -Djava.net.preferIPv4Stack=true
    Then s2i build log should contain -Dfoo=bar
    Then run sh -c 'test -d /home/jboss/.m2/repository/org && echo oops || echo all good' in container and immediately check its output for all good

  #CLOUD-512: Copy configuration files, after the build has had a chance to generate them.
  Scenario: custom configuration deployment for existing and dynamically created files
    Given s2i build https://github.com/jboss-openshift/openshift-examples from eap-dynamic-configuration
    Then XML file /opt/eap/standalone/configuration/standalone-openshift.xml should have 1 elements on XPath //*[local-name()='root-logger']/*[local-name()='level'][@name='DEBUG']

  # CLOUD-1145 - base test
  Scenario: Check custom war file was successfully deployed via CUSTOM_INSTALL_DIRECTORIES
    Given s2i build https://github.com/jboss-openshift/openshift-examples.git from custom-install-directories
      | variable   | value                    |
      | CUSTOM_INSTALL_DIRECTORIES | custom   |
    Then file /opt/eap/standalone/deployments/node-info.war should exist

  # CLOUD-1145 - CSV test
  Scenario: Check all modules are successfully deployed using comma-separated CUSTOM_INSTALL_DIRECTORIES value
    Given s2i build https://github.com/jboss-openshift/openshift-examples.git from custom-install-directories
      | variable   | value                    |
      | CUSTOM_INSTALL_DIRECTORIES | foo,bar  |
    Then file /opt/eap/standalone/deployments/foo.jar should exist
    Then file /opt/eap/standalone/deployments/bar.jar should exist

  # https://issues.jboss.org/browse/CLOUD-1168
  Scenario: Make sure that custom data is being copied
    Given s2i build https://github.com/jboss-openshift/openshift-examples.git from helloworld-ws
      | variable    | value                           |
      | APP_DATADIR | src/main/java/org/jboss/as/quickstarts/wshelloworld |
    Then file /opt/eap/standalone/data/HelloWorldService.java should exist
     And file /opt/eap/standalone/data/HelloWorldServiceImpl.java should exist
     And run stat -c "%a %n" /opt/eap/standalone/data in container and immediately check its output contains 775 /opt/eap/standalone/data

  # https://issues.jboss.org/browse/CLOUD-1143
  Scenario: Make sure that custom data is being copied even if no source code is found
    Given s2i build https://github.com/jboss-openshift/openshift-examples.git from binary
      | variable    | value                           |
      | APP_DATADIR | deployments |
    Then file /opt/eap/standalone/data/node-info.war should exist
     And run stat -c "%a %n" /opt/eap/standalone/data in container and immediately check its output contains 775 /opt/eap/standalone/data

  Scenario: Make sure SCRIPT_DEBUG triggers set -x in build
    Given s2i build https://github.com/jboss-openshift/openshift-examples.git from binary
      | variable     | value       |
      | APP_DATADIR  | deployments |
      | SCRIPT_DEBUG | true        |
    Then s2i build log should contain + log_info 'Script debugging is enabled, allowing bash commands and their arguments to be printed as they are executed'

  # test incremental builds; handles custom module test; custom config test
  Scenario: Check custom modules and configs are copied in; check incremental builds cache .m2
    Given s2i build https://github.com/jboss-openshift/openshift-examples from helloworld
       | variable   | value                                                                                  |
       | MAVEN_ARGS | -e -P jboss-eap-repository-insecure,-securecentral,insecurecentral -DskipTests package |
    Then file /opt/eap/standalone/configuration/standalone-openshift.xml should contain <driver name="postgresql94" module="org.postgresql94">
     And container log should contain JBAS010404: Deploying non-JDBC-compliant driver class org.postgresql.Driver (version 9.4)
     And s2i build log should contain Downloading:
     And check that page is served
        | property | value                        |
        | path     | /jboss-helloworld/HelloWorld |
        | port     | 8080                         |
    Given s2i build https://github.com/jboss-openshift/openshift-examples from helloworld with env and incremental
    Then s2i build log should not contain Downloading:

  # handles binary deployment
  Scenario: deploys the spring-eap6-quickstart example, then checks if it's deployed.
    Given s2i build https://github.com/jboss-openshift/openshift-examples from spring-eap6-quickstart
    Then container log should contain Initializing Spring FrameworkServlet 'jboss-as-kitchensink'
    Then container log should contain JBAS015859: Deployed "ROOT.war"

  Scenario: deploys the binary example, then checks if both war files are deployed.
    Given s2i build https://github.com/jboss-openshift/openshift-examples from binary
    Then container log should contain JBAS015874
    And available container log should contain JBAS015859: Deployed "node-info.war"
    And file /opt/eap/standalone/deployments/node-info.war should exist
    And available container log should contain JBAS015859: Deployed "top-level.war"
    And file /opt/eap/standalone/deployments/top-level.war should exist

   # test multiple artifacts via ARTIFACT_DIR
   Scenario: Check custom modules and configs are copied in; check incremental builds cache .m2
   Given s2i build https://github.com/jboss-developer/jboss-eap-quickstarts from inter-app using 6.4.x
      | variable   | value                                                                                  |
      | ARTIFACT_DIR | appA/target,appB/target,shared/target |
   Then container log should contain JBAS015859: Deployed "jboss-inter-app-shared.jar"
   Then container log should contain JBAS015859: Deployed "jboss-inter-app-appB.war"
   Then container log should contain JBAS015859: Deployed "jboss-inter-app-appA.war"
