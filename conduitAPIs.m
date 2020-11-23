conduitAPIs ; Conduit API handler functions
 ;
 ;----------------------------------------------------------------------------
 ;| mgweb-conduit: mg-web Implementation of the Conduit Back-end             |
 ;|                                                                          |
 ;| Copyright (c) 2020 M/Gateway Developments Ltd,                           |
 ;| Redhill, Surrey UK.                                                      |
 ;| All rights reserved.                                                     |
 ;|                                                                          |
 ;| http://www.mgateway.com                                                  |
 ;| Email: rtweed@mgateway.com                                               |
 ;|                                                                          |
 ;|                                                                          |
 ;| Licensed under the Apache License, Version 2.0 (the "License");          |
 ;| you may not use this file except in compliance with the License.         |
 ;| You may obtain a copy of the License at                                  |
 ;|                                                                          |
 ;|     http://www.apache.org/licenses/LICENSE-2.0                           |
 ;|                                                                          |
 ;| Unless required by applicable law or agreed to in writing, software      |
 ;| distributed under the License is distributed on an "AS IS" BASIS,        |
 ;| WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. |
 ;| See the License for the specific language governing permissions and      |
 ;|  limitations under the License.                                          |
 ;----------------------------------------------------------------------------
 ;
 ; 22 November 2020
 ;
 QUIT
 ;
addError(type,text,errors) ;
  n id
  s id=$increment(errors("errors",type))
  s errors("errors",type,id)=text
  QUIT 1
  ;
bodyAndFields(req,category,requiredFields,optionalFields,errors) ;
  ;
  n field,noFields
  ;
  k errors
  ;
  i '$d(req("body"))!('$d(req("body",category))) d  QUIT
  . i $$addError("body","can't be empty",.errors)
  i $d(requiredFields) d
  . s field=""
  . f  s field=$o(requiredFields(field)) q:field=""  d
  . . i '$d(req("body",category,field)) d  q
  . . . i $$addError(field,"must be defined",.errors)
  . . i req("body",category,field)="" d  q
  . . . i $$addError(field,"can't be empty",.errors)
  i $d(optionalFields),optionalFields'="" d
  . s field=""
  . s noFields=1
  . f  s field=$o(optionalFields(field)) q:field=""  d
  . . i $d(req("body",category,field)) d  q
  . . . s noFields=0
  . . . i req("body",category,field)="" d  q
  . . . . i $$addError(field,"can't be blank",.errors)
  . i noFields d
  . . i $$addError(field,"doesn't contain any of the expected fields",.errors)
  QUIT $d(errors)
  ;
errorResponse(errors,statusCode) ;
  ;
  n crlf,header,json
  ;
  m ^errors($h)=errors
  i '$d(statusCode) s statusCode=422
  s json=$$arrayToJSON^%zmgwebUtils("errors")
  s crlf=$c(13,10)
  s header="HTTP/1.1 "_statusCode_" Not Found"_crlf
  s header=header_"Content-type: application/json"_crlf_crlf
  QUIT header_json
  ;
authenticate(req,res) ;
  ;
  n claims,failReason,id,jwtToken,payload,secret,valid
  ;
  m ^auth("req")=req
  i '$d(req("headers","authorization")) d  QUIT 0
  . s res("error")="Missing authorization"
  ;
  s jwtToken=$p(req("headers","authorization"),"Token ",2)
  i jwtToken="" d  QUIT 0
  . s res("error")="Missing JWT"
  ;
  s ^auth("jwt")=jwtToken
  s secret=$$getJWTSecret^%zmgwebJWT()
  s ^auth("secret")=secret
  s valid=$$authenticateJWT^%zmgwebJWT(jwtToken,secret,.failReason)
  i 'valid d  QUIT 0
  . s res("error")="Invalid JWT: "_failReason
  ;
  s payload=$$decodeJWT^%zmgwebJWT(jwtToken)
  i payload="" d  QUIT 0
  . s res("error")="Missing JWT Payload"
  i $$parseJSON^%zmgwebUtils(payload,.claims)
  i $g(claims("iss"))'=$$getIssuer^%zmgwebJWT() d  QUIT 0
  . s res("error")="Invalid JWT Issuer"
  i $g(claims("email"))="" d  QUIT 0
  . s res("error")="No email in JWT"
  s id=$$idByEmail^conduitUsers(claims("email"))
  i id="" d  QUIT 0
  . s res("error")="Unrecognised email in JWT"
  ;
  s claims("id")=id
  m res=claims
  ;
  QUIT 1
  ;
checkAuthorization(req,errors) ;
 ;
 n byUserId,claims
 ;
 k errors
 s byUserId=""
 i $d(req("headers","authorization")) d
 . i '$$authenticate(.req,.claims) d 
 . . s errors("errors","JWT",1)=claims("error")
 . e  d
 . . s byUserId=claims("id")
 QUIT byUserId
 ;
mustAuthenticate(req,errors)
 ;
 n claims,id
 ;
 k errors
 s id=""
 i '$$authenticate(.req,.claims) d
 . s errors("errors","JWT",1)=claims("error")
 e  d
 . s id=claims("id")
 QUIT id
 ;
getUserData(id,results) ;
 ;
 n json,payload,user
 ;
 k results
 ;
 i $$get^conduitUsers(id,.user)
 k user("password")
 k user("follows")
 s payload("email")=user("email")
 s user("token")=$$createJWT^%zmgwebJWT(.payload,5184000)
 m results("user")=user
 QUIT 1
  ;

trace(text) ;
 n id
 i '$d(text) s text=$h
 s id=$increment(^trace)
 s ^trace(id)=text
 QUIT
 ;
  ; ===========================
  ;
ping(req) ;
 n res
 s res("pong")="true"
 QUIT $$response^%zmgwebUtils(.res)
 ;
getTags(req) ;
 ;
 n json,tags
 ;
 ; no authorization needed
 ;
 i $$getTags^conduitArticles(.tags)
 i '$d(tags) d
 . s json="{""tags"":[]}"
 e  d
 . n results
 . m results("tags")=tags
 . s json=$$arrayToJSON^%zmgwebUtils("results")
 QUIT $$header^%zmgweb()_json
 ;
getArticlesList(req) ;
 ;
 n articles,author,byUserId,errors,favorited,json,max,offset,tag
 ;
 s offset=+$g(req("query","offset"))
 s max=+$g(req("query","max"))
 i 'max s max=10
 ;
 s byUserId=$$checkAuthorization(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s author=$g(req("query","author"))
 s tag=$g(req("query","tag"))
 s favorited=$g(req("query","favorited"))
 ;
 i author'="" d
 . i $$byAuthor^conduitArticles(author,byUserId,offset,max,.articles)
 e  i tag'="" d
 . i $$byTag^conduitArticles(tag,byUserId,offset,max,.articles)
 e  i favorited'="" d
 . i $$favoritedBy^conduitArticles(favorited,byUserId,offset,max,.articles)
 e  d
 . i $$latest^conduitArticles(byUserId,offset,max,.articles)
 ;
 i '$d(articles("articles")) d
 . s json="{""articles"":[],""articlesCount"": 0}"
 e  d
 . s json=$$arrayToJSON^%zmgwebUtils("articles")
 QUIT $$header^%zmgweb()_json
 ;
registerUser(req) ;
 ;
 n email,errors,id,password,payload,requiredFields,results
 n secret,user,username
 ;
 s requiredFields("username")=""
 s requiredFields("email")=""
 s requiredFields("password")=""
 i $$bodyAndFields(.req,"user",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s username=req("body","user","username")
 i username'?1A.AN!($l(username)>50) d
 . i $$addError("username","is invalid",.errors)
 i $$usernameExists^conduitUsers(username) d
 . i $$addError("username","has already been taken",.errors)
 ;
 s email=req("body","user","email")
 i $l(email)>255 d
 . i $$addError("email","is invalid",.errors)
 e  d
 . i '$$isValidEmail^%zmgwebUtils(email) d
 . . i $$addError("email","is invalid",.errors)
 . e  d
 . . i $$emailExists^conduitUsers(email) d
 . . . i $$addError("email","has already been taken",.errors)
 ;
 s password=req("body","user","password")
 i $l(password)<6 d
 . i $$addError("password","must be 6 or more characters in length",.errors)
 ;
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 ; Create the persistent User record
 ;
 m user=req("body","user")
 s id=$$create^conduitUsers(.user)
 ;
 ; now retrieve the user object with JWT
 ;
 i $$getUserData(id,.results)
 QUIT $$response^%zmgwebUtils(.results)
 ;
getArticlesFeed(req) ;
 ;
 n articles,errors,id,json,max,offset
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s offset=+$g(req("query","offset"))
 s max=+$g(req("query","limit"))
 i 'max s max=20
 ;
 i $$getFeed^conduitArticles(id,offset,max,.articles)
 i '$d(articles("articles")) d
 . s json="{""articles"":[],""articlesCount"": 0}"
 e  d
 . s json=$$arrayToJSON^%zmgwebUtils("articles")
 QUIT $$header^%zmgweb()_json
 ;
getUser(req) ;
 ;
 n errors,id,results
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 i $$getUserData(id,.results)
 QUIT $$response^%zmgwebUtils(.results)
 ;
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
authenticateUser(req) ;
 ;
 n email,errors,id,ok,password,requiredFields
 ;
 ; check for body with non-empty email and password
 ;
 s requiredFields("email")=""
 s requiredFields("password")=""
 i $$bodyAndFields(.req,"user",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s email=req("body","user","email")
 s password=req("body","user","password")
 s ok=$$authenticate^conduitUsers(email,password)
 i 'ok d  QUIT $$errorResponse(.errors)
 . i $$addError("email or password","is invalid",.errors)
 ;
 ; now retrieve the user object with JWT
 ;
 s id=$$idByEmail^conduitUsers(email)
 i $$getUserData(id,.results)
 QUIT $$response^%zmgwebUtils(.results)
 ;
createArticle(req) ;
 ;
 n article,data,description,errors,id,requiredFields
 n results,title
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s requiredFields("title")=""
 s requiredFields("description")=""
 s requiredFields("body")=""
 i $$bodyAndFields(.req,"article",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s title=req("body","article","title")
 i $l(title)>255 d
 . i $$addError("title","must be no longer than 255 characters",.errors)
 ;
 s description=req("body","article","description")
 i $l(description)>255 d
 . i $$addError("description","must be no longer than 255 characters",.errors)
 ;
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 m data=req("body","article")
 s articleId=$$create^conduitArticles(id,.data)
 ;
 ; now retrieve the article object
 ;
 i $$get^conduitArticles(articleId,id,.article)
 m results("article")=article
 QUIT $$response^%zmgwebUtils(.results)
 ;
getArticleBySlug(req) ;
 ;
 n article,articleId,byUserId,errors,results,slug
 ;
 s byUserId=$$checkAuthorization(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$get^conduitArticles(articleId,byUserId,.article)
 m results("article")=article
 QUIT $$response^%zmgwebUtils(.results)
 ;
getComments(req) ;
 ;
 n articleId,byUserId,comments,errors,json,slug
 ;
 s byUserId=$$checkAuthorization(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$byUser^conduitComments(byUserId,articleId,.comments)
 i '$d(comments) d
 . s json="{""comments"":[]}"
 e  d
 . n results
 . m results("comments")=comments
 . s json=$$arrayToJSON^%zmgwebUtils("results")
 QUIT $$header^%zmgweb()_json
 ;
addComment(req) ;
 ;
 n articleId,body,comment,commentId,errors,id
 n requiredFields,results,slug
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s requiredFields("body")=""
 i $$bodyAndFields(.req,"comment",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 s body=req("body","comment","body")
 s commentId=$$create^conduitComments(id,articleId,body)
 i $$get^conduitComments(commentId,id,.comment)
 ;
 m results("comment")=comment
 QUIT $$response^%zmgwebUtils(.results)
 ;
deleteComment(req) ;
 ;
 n articleId,commentId,errors,id,json,slug
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 s commentId=$g(req("params","id"))
 i commentId="" d  QUIT $$errorResponse(.errors)
 . i $$addError("comment"," Id not defined",.errors)
 ;
 i '$$exists^conduitComments(commentId) QUIT $$notFound^%zmgweb()
 ;
 i $$getAuthor^conduitComments(commentId)'=id d  QUIT $$errorResponse(.errors)
 . i $$addError("comment","not owned by author",.errors)
 ;
 i $$del^conduitComments(commentId)
 s json="{}"
 QUIT $$header^%zmgweb()_json
 ;
updateArticle(req) ;
 ;
 n article,articleId,data,description,errors,id,requiredFields
 n results,slug,title
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s requiredFields("title")=""
 s requiredFields("description")=""
 s requiredFields("body")=""
 i $$bodyAndFields(.req,"article",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s title=req("body","article","title")
 i $l(title)>255 d
 . i $$addError("title","must be no longer than 255 characters",.errors)
 ;
 s description=req("body","article","description")
 i $l(description)>255 d
 . i $$addError("description","must be no longer than 255 characters",.errors)
 ;
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$getAuthor^conduitArticles(articleId)'=id d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," not owned by author",.errors)
 ;
 m data=req("body","article")
 i $$update^conduitArticles(articleId,id,.data)
 ;
 ; now retrieve the article object
 ;
 i $$get^conduitArticles(articleId,id,.article)
 m results("article")=article
 QUIT $$response^%zmgwebUtils(.results)
 ;
deleteArticle(req) ;
 ;
 n articleId,errors,id,json,results,slug
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$getAuthor^conduitArticles(articleId)'=id d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," not owned by author",.errors)
 ;
 i $$del^conduitArticles(articleId)
 ;
 s json="{}"
 QUIT $$header^%zmgweb()_json
 ;
updateUser(req) ;
 ;
 n email,errors,id,image,password,payload,requiredFields,results
 n user,username
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s requiredFields("username")=""
 s requiredFields("email")=""
 i $$bodyAndFields(.req,"user",.requiredFields,"",.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s username=req("body","user","username")
 i username'?1A.AN!($l(username)>50) d
 . i $$addError("username","is invalid",.errors)
 i $$usernameExists^conduitUsers(username) d
 . i $$idByUsername^conduitUsers(username)'=id d
 . . i $$addError("username","has already been taken",.errors)
 ;
 s email=req("body","user","email")
 i $l(email)>255 d
 . i $$addError("email","is invalid",.errors)
 e  d
 . i '$$isValidEmail^%zmgwebUtils(email) d
 . . i $$addError("email","is invalid",.errors)
 . e  d
 . . i $$emailExists^conduitUsers(email) d
 . . . i $$idByEmail^conduitUsers(email)'=id d
 . . . . i $$addError("email","has already been taken",.errors)
 ;
 s password=$g(req("body","user","password"))
 i password'="",$l(password)<6 d
 . i $$addError("password","must be 6 or more characters in length",.errors)
 ;
 s image=$g(req("body","user","image"))
 i image'="" d
 . i $e(image,1,7)'="http://",$e(image,1,8)'="https://" d  q
 . . i $$addError("picture_url"," is an invalid URL",.errors)
 . n imgc
 . s imgc=$e(image,8,$l(image))
 . i imgc["http://"!(imgc["https://") d  q
 . . i $$addError("picture_url"," is an invalid URL",.errors)
 . i image[";"!(image["?") d  q
 . . i $$addError("picture_url"," is an invalid URL",.errors)
 . n c3,c4,revImg
 . s revImg=$reverse(image)
 . s c3=$reverse($e(revImg,1,3))
 . s c4=$reverse($e(revImg,1,4))
 . i c4'="jpeg",c3'="jpg",c3'="gif",c3'="png" d
 . . i $$addError("picture_url"," is an invalid image URL",.errors)
 ;
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 ; Update the persistent User record
 ;
 m user=req("body","user")
 i $$update^conduitUsers(id,.user)
 ;
 ; now retrieve the user object with JWT
 ;
 i $$getUserData(id,.results)
 QUIT $$response^%zmgwebUtils(.results)
 ;
follow(req) ;
 ;
 n errors,id,profile,results,usernameToFollow
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s usernameToFollow=$g(req("params","username"))
 i usernameToFollow="" d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," to follow must be specified",.errors)
 ;
 i $$getUsername^conduitUsers(id)=usernameToFollow d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," cannot be yourself",.errors)
 ;
 i '$$usernameExists^conduitUsers(usernameToFollow) QUIT $$notFound^%zmgweb()
 ;
 i $$follows^conduitUsers(id,usernameToFollow) d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," is already being followed",.errors)
 ;
 i $$follow^conduitUsers(id,usernameToFollow,.profile)
 m results("profile")=profile
 QUIT $$response^%zmgwebUtils(.results)
 ;
unfollow(req) ;
 ;
 n errors,id,profile,results,usernameToUnfollow
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s usernameToUnfollow=$g(req("params","username"))
 i usernameToUnfollow="" d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," to unfollow must be specified",.errors)
 ;
 i $$getUsername^conduitUsers(id)=usernameToUnfollow d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," cannot be yourself",.errors)
 ;
 i '$$usernameExists^conduitUsers(usernameToUnfollow) QUIT $$notFound^%zmgweb()
 ;
 i '$$follows^conduitUsers(id,usernameToUnfollow) d  QUIT $$errorResponse(.errors)
 . i $$addError("username"," is not being followed",.errors)
 ;
 i $$unfollow^conduitUsers(id,usernameToUnfollow,.profile)
 m results("profile")=profile
 QUIT $$response^%zmgwebUtils(.results)
 ;
favorite(req) ;
 ;
 n article,articleId,errors,id,results,slug
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$getAuthor^conduitArticles(articleId)'=id d
 . i $$favorited^conduitUsers(id,articleId)="false" d
 . . i $$favorite^conduitUsers(id,articleId)
 ;
 i $$get^conduitArticles(articleId,id,.article)
 m results("article")=article
 QUIT $$response^%zmgwebUtils(.results)
 ;
unfavorite(req) ;
 ;
 n article,articleId,errors,id,results,slug
 ;
 s id=$$mustAuthenticate(.req,.errors)
 i $d(errors) QUIT $$errorResponse(.errors)
 ;
 s slug=$g(req("params","slug"))
 i slug="" d  QUIT $$errorResponse(.errors)
 . i $$addError("article"," slug not defined",.errors)
 ;
 s articleId=$$getIdBySlug^conduitArticles(slug)
 i articleId="" QUIT $$notFound^%zmgweb()
 ;
 i $$getAuthor^conduitArticles(articleId)'=id d
 . i $$favorited^conduitUsers(id,articleId)="true" d
 . . i $$unfavorite^conduitUsers(id,articleId)
 ;
 i $$get^conduitArticles(articleId,id,.article)
 m results("article")=article
 QUIT $$response^%zmgwebUtils(.results)
 ;