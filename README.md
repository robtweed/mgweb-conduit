# mgweb-conduit: RealWorld Conduit Back-end based on *mg_web*
 
Rob Tweed <rtweed@mgateway.com>
24 November 2020, M/Gateway Developments Ltd [http://www.mgateway.com](http://www.mgateway.com)  

Twitter: @rtweed

Google Group for discussions, support, advice etc: [http://groups.google.co.uk/group/enterprise-web-developer-community](http://groups.google.co.uk/group/enterprise-web-developer-community)


# What is *mgweb-conduit*?

*mgweb-conduit* is a full implementation of the REST back-end for the 
[RealWorld Conduit](https://medium.com/@ericsimons/introducing-realworld-6016654d36b5)
application using [mg_web](https://github.com/chrisemunt/mg_web).

It therefore provides a good example of how you can use *mg_web* to implement your own
REST services.

# What is RealWorld and Conduit?

The back-end specification of the RealWorld Conduit application is 
[fully documented](https://github.com/gothinkster/realworld/tree/master/api)
and provides a standard, well-known and non-trivial example of a REST back-end.

As the Conduit back-end has been implemented using many
[different technologies and/or frameworks](https://github.com/gothinkster/realworld), 
it provides a great way of comparing and contrasting the different development approaches
used for each option.

# Pre-requisites for *mgweb-conduit*

*mgweb-conduit* requires an operational *mg_web* environment on your server.

It adopts the [*mgweb-server*](https://github.com/robtweed/mgweb-server)
pattern for developing JSON-based *mg_web* REST APIs.

*mgweb-conduit* therefore requires either:

- a manually installed and configured system (see the
instructions that are included in the 
[*mg_web* repository](https://github.com/chrisemunt/mg_web)
configured to use 
[*mgweb-server*](https://github.com/robtweed/mgweb-server); or

- one of the pre-built *mgweb-server*
Docker Containers that are available for:

  - Linux: *rtweed/mgweb*
  - Raspberry Pi: *rtweed/mgweb-rpi*

The handler functions used by *mgweb-conduit* 
are written using the M language, and
are compatible with and will run on the following database technologies:

- [InterSystems IRIS](https://www.intersystems.com/products/intersystems-iris/)
- [InterSystems Cach&eacute;](https://www.intersystems.com/products/cache/)
- [YottaDB](https://yottadb.com)


# Installing and Running *mgweb-conduit* With the *mgweb-server* Docker Containers

The quickest and simplest way to try out the *mgweb-conduit* respository
is by using it in conjunction with one of the *mgweb-server* Docker
Containers.

Follow these steps:

- You need to have Docker and *git* installed on your host system.

- Decide where on your system you'll clone and install the *mgweb-conduit*
repository.  I'm going to assume you'll put it under your home
directory:

        cd ~
        git clone https://github.com/robtweed/mgweb-conduit

Get the latest version of the *mgweb-server* Container:

- Linux:

        docker pull rtweed/mgweb

- Raspberry Pi:

        docker pull rtweed/mgweb-rpi

Then start it up using:

- Linux:

        docker run -d --name mgweb --rm -p 3000:8080 -v /home/ubuntu/mgweb-conduit:/opt/mgweb/mapped rtweed/mgweb

- Raspberry Pi:

        docker run -d --name mgweb --rm -p 3000:8080 -v /home/pi/mgweb-conduit:/opt/mgweb/mapped rtweed/mgweb-rpi

  Note: you can change:

  - the container name (eg *mgweb*) to whatever you like
  - the listener port (eg 3000) to whatever you like

  Change the host volume name containing the cloned
  *mgweb-conduit* repository (eg /home/ubuntu/mgweb-conduit) to whatever 
  is correct for your system

The *mgweb-server* Container includes a pre-installed copy of the
*mgWebComponents*-based RealWorld Client which you can use to run
the RealWorld application against the *mgweb-conduit* REST back-end.

Open a browser and enter the URL:

        http://**.**.**.**:3000/conduit-wc

        (replace **.**.**.** with the IP address or domain name of your server)

It should all burst into life.  Begin by registering a new user, then add an article,
add some comments.



# *mgweb-conduit*'s Components

*mgweb-conduit* is a typical example of how to create an
*mg_web* application that follows the *mgweb-server* pattern.

As such, it contains the following key components:

## *routes.json* File

This file defines the full set of Conduit REST APIs as a JSON-formatted file
which is used to construct the routing Global used by *mgweb-server*.

## *config.json* File

This file defines the JSON Web Token (JWT) issuer for the *mgweb-conduit*
back-end.

## The M Handler Routines

In the *routes.json* file you will see that all the REST API handler
function interfaces reside within a single M routine named *^conduitAPIs*.

The M logic for manipulating and maintaining the persistent data 
(ie the M Globals) required by the Conduit application is
in three other M routines, one for each of the core Conduit data
structures:

- Users: *^conduitUsers*
- Articles: *^conduitArticles*
- Comments: *^conduitComments*

If you want to see how M Globals have been used to model the Conduit
data structures, study these routines.

The M Global structures follow the exact same 
[data model](https://github.com/robtweed/qewd-conduit/blob/master/QEWD-JSdb.md)
 used by the Node.js/QEWD-based 
[*qewd-conduit*](https://github.com/robtweed/qewd-conduit)
project.  The only difference is that *qewd-conduit* abstracts the
physical Global structures as persistent JSON objects.  In
*mgweb-conduit* you are using the exact same underlying
Global structures, accessed directly in M code.

### The API Signature and Pattern

All the *mgweb-conduit* APIs are implemented using the *mgweb-server*
pattern.  Let's use one example to illustrate this:

The API for fetching a user's profile is defined in the *routes.json* file as:

        {
          "uri": "/api/profiles/:username",
          "method": "GET",
          "handler": "getProfile^conduitAPIs"
        }

Note the third part of the uri path is a variable, specifying an
actual user name,eg:

        /api/profiles/rtweed

The handler function (*getProfile^conduitAPIs*)
is shown below:

        getProfile(req) ;
         ;
         n byUserId,errors,ofUserId,profile,results,username
         ;
         s byUserId=$$checkAuthorization(.req,.errors)
         i $d(errors) QUIT $$errorResponse(.errors)
         ;
         i $g(req("params","username"))="" d  QUIT $$errorResponse(.errors)
         . i $$addError("username","must be specified",.errors)
         s username=req("params","username")
         i '$$usernameExists^conduitUsers(username) QUIT $$notFound^%zmgweb()
         ;
         s ofUserId=$$idByUsername^conduitUsers(username)
         i $$getProfile^conduitUsers(ofUserId,byUserId,.profile)
         m results("profile")=profile
         QUIT $$response^%zmgwebUtils(.results)
         ;

The *req* input argument contains 
[parsed details](https://github.com/robtweed/mgweb-server#the-req-argument) 
of the incoming request.

The incoming JWT, if present, is first checked for validity and to confirm
that it hasn't expired.  If OK, the user Id is extracted from the JWT. Take
a look at the *checkAuthorization()* function in the *^conduitAPIs*
routine to see how it works.  It makes use of a suite of JWT handling
APIs that are included in the *mgweb-server* routines, so, for your
own applications, simply re-use and adapt the code appropriately.

The username that was specified in the *uri* path is then checked.  As
you can see this is automatically made available to you by *mgweb-server* as:

        req("params","username")

If the username exists in the *^conduitUsers* global, the user's profile
can then be retrieved:

         i $$getProfile^conduitUsers(ofUserId,byUserId,.profile)

After mapping into a *results* array which ensures the correct
response format, the array is then converted to the
corresponding JSON and returned along with the correctly-structured
HTTP header:

         QUIT $$response^%zmgwebUtils(.results)


As you can see, all the low-level "plumbing" of *mg_web* is being handled
by the *mgweb-server* APIs, leaving you to just focus on how each of your
API handlers needs to work.  What they do and how they work is entirely up
to you.

----------

# Setting up *mgweb-conduit* on an IRIS System

It's easiest to describe how to set up the IRIS Community Edition
Docker Container for use with *mgweb-server*.  Once you understand how it's
done, you can manually perform the equivalent installation steps on any 
non-Dockerised IRIS system.

1) Ensure that you've installed and set up *mg_web* and *mgweb-server*
on your IRIS system.  Read the 
[instructions here](https://github.com/robtweed/mgweb-server#using-the-mgweb-server-container-with-iris).


2) Clone the *mgweb-conduit* repository on your host system

Clone this into the same host directory that you used for *mgweb-server* and *mgsi*.

For example:


        cd ~/mgweb
        git clone https://github.com/robtweed/mgweb-conduit

I'll assume you've already started the IRIS container, mapping the host *mgweb* directory
to the Container's */home/irisowner/mgweb* directory.

3) Shell into the IRIS Container:

        docker exec -it my-iris bash

4) Run the ObjectScript installation script:

        iris session IRIS < mgweb/mgweb-conduit/conduit_install_iris.txt

*mgweb-conduit* will now be ready to use.

Now, when you send REST requests to Apache running on your *mgweb-server* Container,
they will be serviced by the *mgweb-server* and *mgweb-conduit* routines running
in the IRIS Container!


If you want to set up a non-Dockerised IRIS system, take a look at the
*conduit_install_iris.txt* ObjectScript file.  Basically you just need to
install the *mgweb-conduit* routines from the *conduitAPIs.ro* file, and
then run the configuration steps to build the REST API routes global and set
the JWT Issuer value.



----------------
# License

 Copyright (c) 2020 M/Gateway Developments Ltd,                           
 Redhill, Surrey UK.                                                      
 All rights reserved.                                                     
                                                                           
  http://www.mgateway.com                                                  
  Email: rtweed@mgateway.com                                               
                                                                           
                                                                           
  Licensed under the Apache License, Version 2.0 (the "License");          
  you may not use this file except in compliance with the License.         
  You may obtain a copy of the License at                                  
                                                                           
      http://www.apache.org/licenses/LICENSE-2.0                           
                                                                           
  Unless required by applicable law or agreed to in writing, software      
  distributed under the License is distributed on an "AS IS" BASIS,        
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
  See the License for the specific language governing permissions and      
   limitations under the License.      


