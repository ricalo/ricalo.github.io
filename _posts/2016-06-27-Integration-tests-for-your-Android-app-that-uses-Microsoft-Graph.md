---
layout: post
title: Integration tests for your Android app that uses Microsoft Graph
modified:
categories:
  - Android
  - Office365
  - MSGraph
excerpt: >
  Learn how to get an access token to use in your integration tests for your
  Android app. Use the JUnit framework to test your app integration with
  Microsoft Graph.
tags:
  - testing
date: 2016-06-27T10:13:25-07:00
comments: true
---

You can create tests that exercise the integration of your Android app with
services like Microsoft Graph. You can get an access token using the Resource
Owner Password Credentials grant in OAuth 2.0 is your service supports it.
Then you can use the access token in your test framework, like JUnit.

Browse the full example in the
[ConnectUnitTests.java](https://github.com/microsoftgraph/android-java-connect-rest-sample/blob/master/app/src/test/java/com/microsoft/office365/connectmicrosoftgraph/ConnectUnitTests.java)
file of the
[Connect sample for Android](https://github.com/microsoftgraph/android-java-connect-rest-sample).

Do you need UI Automation tests on Android? Check
[UI Automated tests for your Android app that uses Microsoft Graph](../ui-automation-tests-for-your-android-app-that-uses-microsoft-graph-with-Visual-Studio-Team-Services)
instead.

## Use the Resource Owner Password Credentials Grant to get an access token

OAuth 2.0 defines the
[Resource Owner Password Credentials Grant](https://tools.ietf.org/html/rfc6749#section-4.3),
that we can use to get an access token without user interaction. The grant
flow consists in a single POST request to the authorization server that
includes a valid username and password. The authorization server responds with
an access token for the specified user.

> **Note:** It's up to the authorization server whether to implement the
> Resource Owner Password Credentials grant flow or not. Azure Active
> Directory implements the flow, this means that we can use a username and
> password of an Azure Active Directory account in our tests.

The following figure explains the Resource Owner Password Credentials grant
flow.

     +---------+                                  +---------------+
     |         |>------- Username/Password ------>|               |
     |         |                                  | Authorization |
     | Client  |                                  |     Server    |
     |         |<--------- Access Token ---------<|               |
     +---------+                                  +---------------+

            Figure: Resource Owner Password Credentials Flow

> **Important:** You should only use this grant when there is a high degree of
> trust between the resource owner and the client. Don't use a username and
> password of an account that stores valuable data, use an account created
> specifically for testing.

### Example POST request for the Resource Owner Password Credentials grant

The following table summarizes the POST request required to obtain the access
token via the grant.

| Parameter | Value                                                 |
|----------:|-------------------------------------------------------|
|   Scheme: | https                                                 |
|     Host: | login.microsoftonline.com                             |
|  Section: | /common/oauth2/token                                  |
|  Headers: |                                                       |
|           | Content-type: application/x-www-form-urlencoded       |
|     Body: |                                                       |
|           | grant_type: password                                  |
|           | resource: https://graph.microsoft.com                 |
|           | client_id: *your_app_client_id*                       |
|           | username: *your_username@your_tenant.onmicrosoft.com* |
|           | password: *your_password*                             |

Here's the raw body in URL-encoded format.

```
grant_type=password&resource=https%3A%2F%2Fgraph.microsoft.com&client_id=*your_app_client_id*&username=*your_username%40your_tenant.onmicrosoft.com*&password=*your_password*
```

### Example response for the Resource Owner Password Credentials grant

The Microsoft Graph authorization service responds with the following values. 

```
{
  "token_type": "Bearer",
  "scope": "Mail.Send User.Read",
  "expires_in": "3600",
  "expires_on": "1465325263",
  "not_before": "1465321363",
  "resource": "https://graph.microsoft.com",
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSU...",
  "refresh_token": "AAABAAAAiL9Kn2Z27UubvWFPbm0gL..."
}
```

> **Note:** You should verify the access token for validity.
> [Validate an Exchange identity token](https://dev.office.com/docs/add-ins/outlook/validate-an-identity-token)
> shows a method to validate a token. We'll skip this step for the sake of
> brevity.

## Getting the access token during the test setup

You can request one access token to use across multiple tests. Access tokens
from Microsoft Graph last for about an hour, which should cover most scenario
. In this case, you can request the access token during your test setup and
make it available for all your tests.

The following code shows an example of a method annotated with **@BeforeClas
**. This annotation ensures that the method is executed once before running
the tests in the class.

```java
@BeforeClass
public static void getAccessTokenUsingPasswordGrant() 
    throws  IOException, 
            KeyStoreException, 
            NoSuchAlgorithmException, 
            KeyManagementException, 
            JSONException {
    URL url = new URL("https://login.microsoftonline.com/common/oauth2/token");
    HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();

    String urlParameters = String.format(
      "grant_type=%1$s&resource=%2$s&client_id=%3$s&username=%4$s&password=%5$s",
      "password",
      URLEncoder.encode("https://graph.microsoft.com", "UTF-8"),
      "your_app_client_id",
      URLEncoder.encode("your_username%40your_tenant.onmicrosoft.com", "UTF-8"),
      URLEncoder.encode("your_password", "UTF-8")
    );

    connection.setRequestMethod("POST");
    connection.setRequestProperty(
        "Content-Type",
        "application/x-www-form-urlencoded"
    );
    connection.setRequestProperty(
        "Content-Length",
        String.valueOf(urlParameters.getBytes("UTF-8").length)
    );

    connection.setDoOutput(true);
    DataOutputStream dataOutputStream =
        new DataOutputStream(connection.getOutputStream());
    dataOutputStream.writeBytes(urlParameters);
    dataOutputStream.flush();
    dataOutputStream.close();

    connection.getResponseCode();

    BufferedReader in = new BufferedReader(
            new InputStreamReader(connection.getInputStream()));
    String inputLine;
    StringBuffer response = new StringBuffer();

    while ((inputLine = in.readLine()) != null) {
        response.append(inputLine);
    }
    in.close();

    JsonParser jsonParser = new JsonParser();
    JsonObject grantResponse = (JsonObject)jsonParser.parse(response.toString());

    // Store the access token in a member variable that your tests can use
    accessToken = grantResponse.get("access_token").getAsString();
}
``` 

Your test suite has an access token that the individual tests can use to make
authenticated requests to Microsoft Graph.

## Using the access token in the individual tests

The following test is an example of how to use the access token in a JUnit test.
The app uses [Retrofit 2.0](http://square.github.io/retrofit/), which accepts an
interceptor that we can use to inject the access token in every HTTP request.

```java
@Test
public void sendMail_messageSent() throws IOException {
    Interceptor interceptor = new Interceptor() {
        @Override
        public Response intercept(Chain chain) throws IOException {
            Request request = chain.request();
            // Use member variable that our test setup already populated
            // with a valid access token from Microsoft Graph
            request = request.newBuilder()
                    .addHeader("Authorization", "Bearer " + accessToken)
                    .build();

            Response response = chain.proceed(request);
            return response;
        }
    };

    MSGraphAPIController controller = new MSGraphAPIController(interceptor);
    Call<Void> result = controller.sendMail(username, SUBJECT, BODY);
    retrofit2.Response response = result.execute();

    Assert.assertTrue(
        "HTTP Response was not successful", 
        response.isSuccessful()
    );
}
```

In the case of this app, the **MSGraphAPIController** controller object
provides a constructor overload which allows us to provide a custom interceptor.
The default constructor is used for the normal operation of the app, while
the constructor that accepts an interceptor is used in the integration tests.

I hope this is article helps you increase the quality of your apps that use
Microsoft Graph.

Happy testing!

