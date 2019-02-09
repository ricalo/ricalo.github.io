---
layout: post
title: Updating an app to use Microsoft Graph
modified:
categories:
  - Android
  - Office365
  - MSGraph
excerpt: A few weeks ago I updated an Android app to use Microsoft Graph instead
  of the individual endpoints offered by the underlying services that support
  Office 365.
tags:
date: 2016-03-01T08:00:00-08:00
share: true
comments: true
---

During the last few weeks, I updated an Android app that I use to showcase
Office 365 features for developers. The app was using the independent endpoints
exposed by the underlying services that support Office 365 instead of the new
Microsoft Graph.

The app itself is
[Meeting Feedback](https://github.com/OfficeDev/O365-Android-MeetingFeedback),
it allows users to provide anonymous feedback to the meetings that they attend.
The purpose of this sample is that developers will come up with ideas on their
own about how to use Office 365 data and services in their own apps.

As you can imagine, it's important to use the latest and greatest Office 365
features in this type of apps. This is why I decided to upgrade the app to use
Microsoft Graph. In this article, I'll describe the process of upgrading the
app, as well as some of the benefits.

## Discovery service gone

Before your app can use Office 365 services, it has to "discover" the services
endpoints. Depending on the service that you want to use, Office 365 has an
endpoint that might be different per individual user in the case of OneDrive for
Business or the same endpoint as is the case with Outlook.

Office 365 offers the
[Discovery Service](https://msdn.microsoft.com/office/office365/howto/discover-service-endpoints)
to make it easy for your app to find the endpoint that it needs to use a
particular service.

Now, with Microsoft Graph, we only have one endpoint.

```
https://graph.microsoft.com
```

What does that mean for your app? Well, a couple of different things.

1. Your app won't have to query the Discovery Service anymore. In the past,
developers had to find the endpoints, usually at app start time. No more! Your
app will start quicker.
2. If you're using
[ADAL](https://github.com/AzureAD/azure-activedirectory-library-for-android/) to
get tokens, you might be familiar with the following code:

~~~ java
public void setResourceId(final String resourceId) {
    this.mResourceId = resourceId;
    this.mDependencyResolver.setResourceId(resourceId);
}
~~~

The idea here is that whenever you want to get an access token, you must set the
resource id to the endpoint of the service that you want to get the access token
for.

As you can imagine, it's easy to forget to set the resource id to the right
endpoint. This can lead to wasted time trying to figure out why the access token
doesn't work in your request.

This is also gone with Microsoft Graph. Set your endpoint once, and forget about
it.

## Using a library to hit Graph endpoints

Each platform has a great library that we can use to make requests to REST
endpoints. In the case of Android and Java, that library is
[Retrofit](http://square.github.io/retrofit/) (in my opinion, of course).

Retrofit makes it easy to define interfaces and POJOs that adhere to the
contract of Microsoft Graph endpoints. Additionally, it's easy to intercept the
requests to inject an authorization header right before sending them through the
wire.

~~~ java
RequestInterceptor requestInterceptor = new RequestInterceptor() {
    @Override
    public void intercept(final RequestFacade request) {
        try {
            AuthenticationResult authenticationResult = 
                (AuthenticationResult)mAuthenticationManager
                    .authenticateSilent(null)
                    .get();
            request.addHeader(
                "Authorization", "Bearer " +
                authenticationResult.getAccessToken()
            );
        } catch (InterruptedException | ExecutionException e) {
            Log.e(TAG, e.getMessage());
        }
    }
};
~~~

In the previous code, note that we're appending the access token to the
authorization header for every single request. No need to do this anywhere else
in the app. Even better, the access token is obtained from the
`authenticateSilent` method just one line above. This means that most of the
time, the token will be retrieved from ADAL's cache. If there's no viable token
in cache, then the token must be obtained via the refresh flow, which is also
taken care by `authenticateSilent`!

![interceptor](/images/interceptor.png 'Interceptor injecting access tokens on outbound HTTP requests')

Just one small caveat, you must ensure that this code is not running in the main
thread, or the app will fail whenever `authenticateSilent` tries to get a token
using the refresh flow.

## CalendarView, an endpoint example

As you can imagine, the most important workload for Meeting Feedback is the
calendar. Microsoft Graph offers endpoints that you can use to integrate Outlook
calendar in your apps. 

One of particular interest to me is *CalendarView*. As the name implies, the
*CalendarView* is an endpoint optimized for read operations, it even offers a
couple of query string parameters, `startDateTime` and `endDateTime`, that you
can use to get just the range of data that you need.

As expected, you can also add `$select`, `$orderby` and other REST operators to
further customize your query. I ended up with the following request.

~~~
HTTP GET https://graph.microsoft.com/v1.0/me/calendarview?
startdatetime=2016-01-29T16%3A57%3A00.2910000&
enddatetime=2016-02-26T16%3A57%3A00.2910000
$select=subject%2Cstart%2Cend%2Corganizer%2CisOrganizer%2Cattendees%2CbodyPreview%2CiCalUID&
$orderby=start%2Fdatetime+desc&
$top=150
~~~

Which can be executed by this Retrofit GET request.

~~~ java
public interface CalendarInterface {
    @GET("/me/calendarview")
    void getEvents(
            @Header("Content-type") String contentTypeHeader,
            @Header("Prefer") String preferHeader,
            @Query("startdatetime") String startDateTime,
            @Query("enddatetime") String endDateTime,
            @Query("$select") String select,
            @Query("$orderby") String orderBy,
            @Query("$top") String top,
            Callback<Envelope<Event>> callback
    );
}
~~~

One additional detail about the method above is the `Prefer` header. The service
can send you back the events formatted with dates in the timezone that you
specify in the header. Just set this to the timezone of the device your app is
running on and voila! No more worrying about converting from UTC to your current
time, Office 365 takes care of that.

## Going back to the code

As always, when I go back to the code I find bugs and better ways to accomplish
a task. But I also find ideas that I'd like to implement sometime.
[Meeting Feedback](https://github.com/OfficeDev/O365-Android-MeetingFeedback)
would benefit greatly from the following features:

- Offline support. Allow users to rate meetings even if they have no network.
  Sync the data when the device has connectivity.
- Voice support. Provide a voice command to easily rate the meeting and add
  comments.

Have any ideas yourself? Tell me in the
[issues](https://github.com/OfficeDev/O365-Android-MeetingFeedback/issues)
section of the repo on GitHub.

I hope you had a sense of what it takes to update your Android app to use
Microsoft Graph. In reality, the process is not very different than updating an
app to use one REST endpoint instead of several. The entities (calendar events,
mails) pretty much remain the same, which makes plugging your existing code in
really easy.

Happy coding!

