---
layout: post
title: Use Docker as your local environment for your GitHub Pages site
modified:
categories:
  - Docker
  - GitHub-Pages
excerpt: >
  Learn how to use a Docker container as your local environment for web
  related projects, such as a Jekyll site that you can deploy on GitHub Pages.
tags:
  - webdev
date: 2016-12-25T12:00:00-07:00
comments: true
---

In the last few years I've been trying to setup and maintain web development
environments across Windows, Mac, and Linux. While there are some tools that
work most of the time, I was looking for something that requires less
maintenance, is easier to setup, and available on-demand while still allowing
me to use my favorite text editors on my host computers.

The answer for me was to setup my environment on Docker containers. In this
article I'll explain how to setup a local development environment for your
Jekyll projects.

> **Note:** [GitHub Pages](https://pages.github.com/) is a free hosting
> service that lets you publish static websites. GitHub Pages uses
> [Jekyll](https://jekyllrb.com/) to generate your static website from a
> template.

## TL;DR

To use a Docker container as the development environment for your Jekyll
project, do the following:

1. Add a `_config_dev.yml` file to the root of your project with the following
   settings:
  * host: 0.0.0.0
  * port: 4000
2. In your terminal, go to the root folder of your project, then type:

``` bash
docker run \
  --tty \
  --name your_container \
  --publish 4000:4000 \
  --restart unless-stopped \
  --volume $(pwd):/usr/src/app \
  ricalo/jekyll \
  serve --config _config.yml,_config_dev.yml
```

> **Note:** On Windows, use the following command:
> ``` bash
> docker run \
>   --tty \
>   --name your_container \
>   --publish 4000:4000 \
>   --restart unless-stopped \
>   --volume c:\path\to\root:/usr/src/app \
>   ricalo/jekyll \
>   serve --config _config.yml,_config_dev.yml --force_polling
> ```


You can edit the files on your host, the container will detect changes and
automatically publish them to your *localhost* server. Go to
`http://localhost:4000` on your browser to see your Jekyll site.

## Setup your development environment for Jekyll projects

In the previous section, I quickly showed how to get your container up-and
running without further explanation. In this section, we'll visit the relevant
options. This should help you understand how to use the same concepts with
other web technologies. We'll review the following aspects of the solution:

* Jekyll development configuration file
* Jekyll Docker image
* Docker run command

### Jekyll development configuration file

Jekyll accepts multiple configuration files when serving a site. For example:

```bash
jekyll serve --config _config.yml,_config_dev.yml
```

The previous command tells Jekyll to use the base configuration settings in 
`_config.yml`, but also use the settings in `_config_dev.yml`. The settings in
the second file will be added to the base configuration, if the same setting
is used in both files, the latter setting overrides the former.

This allows us to specify settings that we can use to serve the file from our
local environment, but using most of our production settings. For example, the
following file specifies a **host**, **port**, and **url** settings.

```yaml
# Development configuration

host:     0.0.0.0
port:     4000
```

It might not be immediately evident, why we need these settings to serve from
localhost. I'll try to explain:

* **Host** - It would be understandable to think that we could use *localhost*
here. However, *localhost* or *127.0.0.1* only respond to requests issued to a
loopback interface. In other words, *localhost* would only work from within
the container. In contrast, *0.0.0.0* responds to requests from all interface
. This allows us to use a browser in our host to visit `http://localhost:4000`
while letting the container serve the request.
* **Port** - This is straightforward. Serve the Jekyll site on port *4000*.
* **Url** - Using *0.0.0.0* as the **host** allows the container to respond to
  requests from all interfaces. The downside is that *0.0.0.0* is a non
  routable address. This means that, on some operating systems, your browser
  won't be able to request resources needed to render the page correctly. For
  example, if your page has an image tag like
  `<img src="http://0.0.0.0/image.png" />` the browser won't display it,
  particularly on Windows. The **url** setting is used throughout the Jekyll
  site in the source attribute of resources like images, stylesheets, and
  JavaScript files.

In the next section, you'll see how this configuration file works with the
Jekyll image.

### Jekyll Docker Image

You might have noticed in the **TL;DR** section that the example uses the
**ricalo/jekyll** image. This image makes it easy to run our environment by
configuring the following:

* Use Ruby 2.3.1 as the base image
* Set the working directory
* Set a default encoding
* Specify a default command to use at run time

The **Ruby** image has everything you need to serve your Jekyll site,
including the **bundler** gem, which we use to install the dependencies needed
by our Jekyll project.

In the ricalo/jekyll image, we set the `/usr/src/app` as the working director
. In the next section we'll add a volume in the container that maps the folder
in the host where you have your project files to `/usr/src/app` in the
container.

Per the [Ruby image docs](https://hub.docker.com/r/_/ruby/), we set the image
encoding to **C.UTF-8** to prevent unexpected results.

Last, but not least, the image specifies the following default command:

```bash
env NOKOGIRI_USE_SYSTEM_LIBRARIES=true bundle install
jekyll build --destination ../_test && htmlproofer --http-status-ignore 999 ../_test &
jekyll serve
```

The command tells the container to install all the dependencies in our project
and serve the site using the configuration in the `_config.yml` and
`_config_dev.yml` files.

In the next section, we'll see how to run the container and map our Jekyll
project to the working directory in the container.

### Docker run command

Finally! We're ready to run our container and serve our Jekyll project. I
recommend to use the following command in the root folder of your project. I
ll explain the flags used below to help you customize the command to your needs.

```bash
docker run \
  --name your_container \
  --publish 4000:4000 \
  --volume $(pwd):/usr/src/app \
  --restart unless-stopped \
  --tty \
  ricalo/jekyll
```

* **docker run** command - Not a lot to explain here, you use this command to
  start the container.
* **name** flag - Assign a human-readable name to your container for easy
  referral in other commands, like `docker attach <name>`.
* **publish** flag - Publish (or map) the 4000 port of the container to the
  4000 port of the host. Requests that go to the 4000 port of the host will be
  handled by the container.
* **volume** flag - Map the current directory in the host to the `/usr/src/app`
  directory in the container. This allows you to use your favorite text editor
  in your host and have the container automatically detect and publish the
  changes you make to your site.
* **restart** flag - I use the *unless-stopped* option to let my container run
  whenever I'm using my host machine. This allows me to work on my site
  whenever I have time without to have to start containers, services or
  anything. Just pull up my text editor and write. The small footprint of the
  container means that my machine performance doesn't hurt even if I have the
  container always up.
* **tty** flag - This allows you to detach from the container by pressing
  <kbd>ctrl + c</kbd>. This is useful if you use `docker attach your_container`
  to see the container output, then you can detach by pressing
  <kbd>ctrl + c</kbd>.
* **ricalo/jekyll** argument - Specifies the image that the container will
  derive from.

At this moment you should wee somethingl ike

```
Bundle complete! 5 Gemfile dependencies, 39 gems now installed.
Bundled gems are installed into /usr/local/bundle.
+ jekyll serve --config _config.yml,_config_dev.yml
Configuration file: _config.yml
Configuration file: _config_dev.yml
            Source: /usr/src/app
       Destination: /usr/src/app/_site
 Incremental build: disabled. Enable with --incremental
      Generating... 
                    done in 2.599 seconds.
 Auto-regeneration: enabled for '/usr/src/app'
Configuration file: _config.yml
Configuration file: _config_dev.yml
    Server address: http://0.0.0.0:4001/
    Server running... press ctrl-c to stop.
```

And eveytime you update a file in your project, you should see:

```
Regenerating: 1 file(s) changed at 2016-12-22 23:10:21 ...done in 1.889933647 seconds.
```

This means the Jekyll service in the container is listening to changes in the
Jekyll project in your host. You might not want to have that terminal window
open all the time, you can close it and the container should keep running in
the background.

## Attach your terminal to the container

In some situations, you'll want to attach your terminal to the container so
you can see the output. This is especially useful if you're running into
syntax errors and you're not seeing the changes reflected in your site. To
attach your terminal to the running container, type:

```bash
docker attach your_container
```

If you update a file, you should see output showing success or failure of the
generation of the corresponding resource.

## Conclusion

The previous artile showed how to setup your local environment on Docker
containers. By using containers, you can setup a cross-platform development
environment that is easy to maintain and always available.

You should be able to expand the lessons learned in this article to other
platforms, like Node.js or PHP. Let me know in the comments if you have any
suggestions of questions.
