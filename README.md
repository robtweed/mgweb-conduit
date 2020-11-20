# mgweb-conduit: RealWorld Conduit Back-end based on *mg_web*
 
Rob Tweed <rtweed@mgateway.com>
20 November 2020, M/Gateway Developments Ltd [http://www.mgateway.com](http://www.mgateway.com)  

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








