conduitComments ; Conduit Comments Database functions
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
 ; 13 November 2020
 ;
 ;
 ; ================
 ;
getNextId() 
 QUIT $increment(^conduitComments("nextid"))
 ;
exists(commentId) ;
 QUIT $d(^conduitComments("byId",commentId))
 ;
getAuthor(commentId) ;
 QUIT $g(^conduitComments("byId",commentId,"author"))
 ;
linkComment(articleId,commentId) ;
 s ^conduitArticles("byId",articleId,"comments",commentId)=commentId
 QUIT 1
 ;
unlinkComment(articleId,commentId) ;
 k ^conduitArticles("byId",articleId,"comments",commentId)
 QUIT 1
 ;
create(authorId,articleId,commentBody) ;
 ;
 n comment,commentid,iso
 ;
 s commentId=$$getNextId()
 s iso=$$UTCDateTime^%zmgwebUtils($$now^%zmgwebUtils())
 s comment("id")=commentId
 s comment("articleId")=articleId
 s comment("body")=commentBody
 s comment("author")=authorId
 s comment("createdAt")=iso
 s comment("updatedAt")=iso
 ;
 m ^conduitComments("byId",commentId)=comment
 i $$linkComment(articleId,commentId)
 ;
 QUIT commentId
 ;
del(commentId,unlinkArticle) ;
 ;
 n articleId,ok
 ;
 i '$d(unlinkArticle) s unlinkArticle=1
 s articleId=$g(^conduitComments("byId",commentId,"articleId"))
 k ^conduitComments("byId",commentId)
 i unlinkArticle s ok=$$unlinkComment(articleId,commentId)
 ;
 QUIT 1
 ;
get(commentId,byUserId,comment) ;
 ;
 n ofUserId,profile
 ;
 k comment
 m comment=^conduitComments("byId",commentId)
 k comment("articleId")
 s ofUserId=comment("author")
 k comment("author")
 i $$getProfile^conduitUsers(ofUserId,byUserId,.profile)
 m comment("author")=profile
 ;
 QUIT 1
 ;
byUser(userId,articleId,comments) ;
 ;
 n commentId
 ;
 k comments
 ;
 ; get comment records for the article
 ;
 s commentId=""
 f  s commentId=$o(^conduitArticles("byId",articleId,"comments",commentId)) q:commentId=""  d
 . n comment,id
 . i $$get(commentId,userId,.comment)
 . s id=$increment(comments)
 . m comments(id)=comment
 ;
 QUIT 1
 ;
