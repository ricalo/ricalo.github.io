---
layout: post
title: Use VSTS to run your UI Automated tests for your Android app
modified:
categories:
  - Android
  - Office365
  - MSGraph
excerpt: >
  Use Visual Studio Team Services and a UI Automation framework to test
  your Android app that uses Microsoft Graph  
tags:
  - testing
date: 2016-06-28T08:00:00-07:00
comments: true
---

Recently, I published an article about [using integration tests in your Android
app that uses Microsoft
Graph](/android/office365/msgraph/Integration-tests-for-your-Android-app-that-uses-Microsoft-Graph/).
However, there are times when you really need to replicate your users' actions
and validate the UI state. For this testing scenarios, you need to create UI
automated tests. In this article we'll see how we can create UI automated tests
for your Android app that uses Microsoft Graph. We'll also explain how we can
configure the tests to run from a Visual Studio Team Services build definition.

You can also see the full sample in the
[`ConnectActivityTests`](https://github.com/microsoftgraph/android-java-connect-sample/blob/master/app/src/androidTest/java/com/microsoft/graph/connect/ConnectActivityTests.java)
class of the
[Connect Sample for Android Using the Microsoft Graph SDK](https://github.com/microsoftgraph/android-java-connect-sample).

## Create the build definition on Visual Studio Team Services

You can run your tests from Visual Studio Team Services by creating a build
definition. A build definition lets you run your tests as part of your
continuous integration or daily build processes.

To create a build definition:

1. Go to a project in your Visual Studio subscription.<br />Don't have one? 
   Start a
   [trial subscription](https://go.microsoft.com/fwlink/?LinkId=307137&clcid=0x409&wt.mc_id=o~msft~vscom~getstarted-hero~dn469161&campaign=o~msft~vscom~getstarted-hero~dn469161).
2. In the top navigation, select **Build**. Then click on the **+** sign to
   create a new build definition.
3. Select an **Empty** build definition (scroll all the way down in the list
   of templates).
4. Select your repository source.<br />For example, I selected the
   [Connect Sample for Android](https://github.com/microsoftgraph/android-java-connect-sample)
   on GitHub.
5. Select your agent queue.<br />Visual Studio Team Services deploys the build,
   including the tests to the agent. The agent must have the required
   components to run the tests, for example, an Android emulator. My Linux
   machine in my office serves as my Visual Studio Agent. 

Now you have an empty build definition. We will use this build definition in
the next steps to configure the test. 

### Define variables in the build definition

One of the advantages of having your build definition on Visual Studio Team
Services is that you can have sensitive data, like username and passwords,
separated from the code. Tests require this data to run, but I wouldn't store
such sensitive information in a public repository on GitHub.

You can add custom variables to a build definition. Variables are named
strings that are available at build time. In this case, I require three
variables to store a client ID, username and a password.

The variables are visible to anybody who has access to the Visual Studio
subscription. This might not a be a big deal for the client ID and username,
but it could be a problem in the case of the password. Visual Studio Team
Services has the concept of *secret variables*, so I can safely store my
password and it will not be revealed to other users, like my teammates.

To define a build definition variable:

1. Go to the **Variables** tab in the build definition.
2. Provide a **Name** and **Value** for your variable.
3. Click the lock icon to make your variable secret.<br />You won't be able to
   see the value again.

For my test, I defined the following variables:

|      Name      |         Value        | Secret? |
|:--------------:|:--------------------:|:-------:|
| test_client_id | *your_app_client_id* |    no   |
|  test_username |    *your_username*   |    no   |
|  test_password |    *your_password*   |   yes   |

## Pass the variables to the Android device

In the case of UI Automated tests, the variables must be available to the
device executing the test. The device running the test is the Android emulator
that lives in the Visual Studio Agent. The variables must travel from Visual
Studio Team Services and ultimately end in the Android emulator.

     +----------+                       +--------+                       +----------+
     | Visual   |     test_client_id    |        |     test_client_id    |          |
     | Studio   |>--- test_username --->| Visual |>--- test_username --->| Android  |
     | Team     |     test_password     | Studio |     test_password     | emulator |
     | Services |                       | Agent  |                       |          |
     +----------+                       +--------+                       +----------+

                        Figure: Build definition variables flow

To make the variables available to the Android device I created a script that
performs the following tasks: 

1. Reads the variables and writes them in a file.
2. Copy the file to the Android device.
3. Define a build step to execute the script.

### Read the variables and write them to a file

Previously in the article, we defined three variables. Two of them are regular
variables, one of them is secret. Regular variables are available as
environment variables in the Visual Studio Agent. The secret variable must be
explicitly passed as an argument to the script.

Since my Visual Studio Agent is a Linux machine, I wrote a bash script. However,
the same concepts apply to batch files on Windows.

The script writes a JSON-formatted string to a **testConfig.json** file. Note
that the **test_client_id** and **test_username** variables are available as
environment variables in the format *$ENV_VARIABLE*. The **test_password**
variable is not available as an environment variable (because it was defined
as a secret variable), hence the script expects it as an argument denoted by
**$1**. 

```bash
#!/bin/bash

testConfig="{
  \"test_client_id\": \"$TEST_CLIENT_ID\",
  \"test_username\": \"$TEST_USERNAME\",
  \"test_password\": \"$1\"
}"
echo $testConfig
echo $testConfig > testConfig.json
```

We'll pass the **test_password** variable later when we invoke the script from
a build step.

### Copy the file to the Android device

To copy the file to the `/data/local` folder in the device we can use the
Android Device Bridge (ADB). Note that the emulator must be running before
executing the script. 

```bash
#!/bin/bash

adb devices | while read line
do
if [ ! "$line" = "" ] && [ `echo $line | awk '{print $2}'` = "device" ]
then
    device=`echo $line | awk '{print $1}'`
    echo "$device $@ ..."
    adb -s $device push testConfig.json ./data/local
fi
done
```
An additional comment about this script is that it copies the file to all the
devices connected to ADB. This is particularly useful because the UI Automated
tests run in all the devices connected to ADB too.

I separated the scripts in this article to make it easier to explain. However,
in practice I consolidated the script in one file called **getTestConfig.sh**.

## Define a build step to execute the script

Now we can go back to the build definition and add a build step to invoke the
script and pass the test_password variable as an argument.

To add the build step:

1. In the build definition click **Add build step...**
2. Select the **Shell script** task.
3. In **Script path** select the **getTestConfig.sh** script.
4. In the **Arguments** textbox type **$(TEST_PASSWORD)**.

Save your build definition.

## Coding the UI Automated test

### Get test parameters from the testConfig.json file

You should get the test parameters once and use them in all the tests. The
test setup is a good place to retrieve the parameters from the testConfig.json
file.
The following code shows the setup method, which is annotated with
**BeforeClass**. This annotation ensures that the method is executed once before
running the tests in the class.

```java
@BeforeClass
public static void getTestParameters() throws FileNotFoundException {
    File testConfigFile = 
        new File(Environment.getDataDirectory(), "local/testConfig.json");
    JsonObject testConfig = 
        new JsonParser().parse(new FileReader(testConfigFile)).getAsJsonObject();
    testClientId = testConfig.get("test_client_id").getAsString();
    testUsername = testConfig.get("test_username").getAsString();
    testPassword = testConfig.get("test_password").getAsString();
}
```

### Simulate user interaction in the test

Now we can start simulating user interaction like tapping UI components or
typing in textboxes. These are some common steps that you might need to follow
in your app. 

1. Configure the client ID for the app
2. Perform click operations
3. Type username and password in the authentication activity
4. Validate the UI state

### Configure the client ID for the app

In the case of the
[Connect sample](https://github.com/microsoftgraph/android-java-connect-sample),
we need to specify a client ID before trying to sign in with user credentials.
The sample exposes the client ID in a property in the
[Constants](https://github.com/microsoftgraph/android-java-connect-sample/blob/master/app/src/main/java/com/microsoft/graph/connect/Constants.java#L10)
class. The following code uses the **testClientId** parameter to configure the
app.

```java
Constants.CLIENT_ID = testClientId;
```

The testClientId parameter contains the client ID of a valid application
registered in the Azure Management Portal. 

### Perform click operations

In the Connect sample, the first action expected from the user is to tap a
button.

```java
onView(withId(R.id.connectButton)).perform(click());
```

Once the user taps the button, the app displays the authentication activity.

### Type username and password in the authentication activity

In the authentication activity, users can type username and password in
textboxes. The textboxes have the identifiers **cred_userid_inputtext** and
**cred_password_inputtext** for username and password respectively.

```java
onWebView()
    .withElement(findElement(Locator.ID, "cred_userid_inputtext"))
    .perform(clearElement())
    // Enter text into the input element
    .perform(DriverAtoms.webKeys(testUsername))
    // Set focus on the username input text
    // The form validates the username when this field loses focus
    .perform(webClick())
    .withElement(findElement(Locator.ID, "cred_password_inputtext"))
    .perform(clearElement())
    // Enter text into the input element
    .perform(DriverAtoms.webKeys(testPassword))
    // Now we force focus on this element to make
    // the username element to lose focus and validate
    .perform(webClick());
```

There are some extra steps that the test should simulate, like tapping in the
textboxes to force focus on them. The authentication activity performs some
validations when the textboxes lose focus, hence the requirement to set focus
on them.

### Validate the UI state

In your test, you should validate that the UI is in the expected state. For
example the following code validates that there is a **SendMailActivity** on
the top of the app and that it has the username in the **displayableId**
intent extra. 

```java
intended(allOf(
        hasComponent(hasShortClassName(".SendMailActivity")),
        hasExtra("displayableId", testUsername),
        toPackage("com.microsoft.graph.connect")
));
```

The **intended** method is an assertion that determines whether the test
passed or failed.

## Invoke the UI Automated test from the build definition

You can run your UI automated tests with the **connectedCheck** task available
in the
[Android Gradle plugin](http://tools.android.com/tech-docs/new-build-system/user-guide).
To add a build step that executes the connectedCheck task follow these steps:

1. In the build definition click **Add build step...**
2. Select the **Gradle** task.
3. In **Gradle wrapper** pick the location of your Gradle wrapper file.
4. In the **Tasks** textbox type **connectedCheck**.

You're ready! Now go and click that **Queue build...** button and watch your
test automatically running in your emulators.

Enjoy!

