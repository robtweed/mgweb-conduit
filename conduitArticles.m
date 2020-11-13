conduitArticles ;
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
slugify(value) ;
 ;
 n slug
 ;
 ; convert value to lower case
 s slug=$zconvert(value,"L")
 ;
 ; remove leading and trailing white-space
 if $zv["GT.M" do
 . s slug=$$FUNC^%TRIM(slug)
 else  do
 . s slug=$zstrip(slug,"<>W")
 ;
 ; convert remaining spaces and tabs to hyphens
 s slug=$tr(slug,$c(9,32,160),"---")
 ; replace diacritics, and some punctuation
 s slug=$tr(slug,"„‡·‰‚?ËÈÎÍÏÌÔÓıÚÛˆÙ˘˙¸˚ÒÁ∑/_,:;","aaaaaeeeeeiiiiooooouuuunc------")
 ;
 if $zv["GT.M" do
 . n go,i,str
 . ; replace ampersand with -and-
 . s slug=$$^%MPIECE(slug,"&","-and-")
 . ; remove any other punctuation apart from hyphens
 . s str=""
 . f i=1:1:$l(slug) d
 . . n char
 . . s char=$e(slug,i)
 . . i char?1P,char'="-" q
 . . s str=str_char
 . s slug=str
 . ; remove anything that isn't a-z, 0-9 or a hyphen
 . s str=""
 . f i=1:1:$l(slug) d
 . . n char
 . . s char=$e(slug,i)
 . . i char?1L s str=str_char q
 . . i char?1N s str=str_char q
 . . i char="-" s str=str_char q 
 . s slug=str
 . ; remove any remaining leading, trailing or duplicate punctuation
 . s str=""
 . s go=0
 . f i=1:1:$l(slug) d
 . . n char
 . . s char=$e(slug,i)
 . . i go s str=str_char q
 . . i char'?1P d
 . . . s go=1
 . . . s str=str_char
 . s slug=str
 . s slug=$reverse(slug)
 . s str=""
 . s go=0
 . f i=1:1:$l(slug) d
 . . n char
 . . s char=$e(slug,i)
 . . i go s str=str_char q
 . . i char'?1P d
 . . . s go=1
 . . . s str=str_char
 . s slug=$reverse(str)
 . s slug=$$^%MPIECE(slug,"--","-")
 . ;
 else  do
 . ; replace ampersand with -and-
 . s slug=$replace(slug,"&","-and-")
 . ; remove any other punctuation apart from hyphens
 . s slug=$zstrip(slug,"*P",,"-")
 . ; remove anything that isn't a-z, 0-9 or a hyphen
 . s slug=##class(%Regex.Matcher).%New("[^a-z0-9-]+", slug).ReplaceAll("")
 . ; remove any remaining leading, trailing or duplicate punctuation
 . s slug=$zstrip(slug, "<>=P")
 ;
 QUIT slug
 ;
getNextId() ;
 QUIT $increment(^conduitArticles("nextId"))
 ;
articleExists(articleId) ;
 QUIT $d(^conduitArticles("byId",articleId))
 ;
getAuthor(articleId) ;
 QUIT ^conduitArticles("byId",articleId,"author")
 ;
slugExists(slug) ;
 QUIT $d(^conduitArticles("bySlug",slug))
 ;
createSlug(title,articleId) ;
 s slug=$$slugify(title)
 if ($$slugExists(slug)) d
 . s slug=slug_"-x"_articleId
 QUIT slug
 ;
getTimeStamp(results) ;
 ;
 n iso,now,ts
 ;
 k results
 s now=$h
 i $zv'["GT.M" s now=$zts
 s iso=$$UTCDateTime^%zmgwebUtils(now)
 ; get reverse chronological index timestamp value
 s ts=100000000000000-$$epochTime^%zmgwebUtils(now)
 s results("iso")=iso
 s results("ts")=ts
 QUIT 1
 ;
 ;
 ; ==========================
 ;
create(authorId,data) ;
 ;
 n article,articleId,iso,n,slug,tag,timestamp,ts
 ;
 s articleId=$$getNextId()
 ;
 ; derive a unique slug based on title
 ;
 s slug=$$createSlug(data("title"),articleId)
 i $$getTimeStamp(.timestamp)
 s ts=timestamp("ts")
 s iso=timestamp("iso")
 ;
 m article=data
 s article("createdAt")=iso
 s article("updatedAt")=iso
 s article("timestampindex")=ts
 s article("favoritesCount")=0
 s article("author")=authorId
 s article("slug")=slug
 ;
 ; save to database
 ;
 m ^conduitArticles("byId",articleId)=article
 ;
 ; create indices
 ;
 s ^conduitArticles("bySlug",slug)=articleId
 s ^conduitArticles("byAuthor",authorId,articleId)=articleId
 s ^conduitArticles("byTimestamp",ts)=articleId
 ;
 s n=""
 f  s n=$o(data("tagList",n)) q:n=""  d
 . s tag=data("tagList",n)
 . s ^conduitArticles("byTag",tag,articleId)=articleId
 ;
 QUIT articleId
 ;
del(articleId) ;
 ;
 n authorId,slug,n,tag,ts
 ;
 i '$$articleExists(articleId) QUIT
 ;
 s slug=$g(^conduitArticles("byId",articleId,"slug"))
 k ^conduitArticles("bySlug",slug) 
 ; delete author index
 s authorId=$$getAuthor(articleId)
 k ^conduitArticles("byAuthor",authorId,articleId) 
 ; delete timestamp index
 s ts=$g(^conduitArticles("byId",articleId,"timestampindex"))
 k ^conduitArticles("byTimestamp",ts) 
 ; delete tagList indices
 s n=""
 f  s n=$o(^conduitArticles("byId",articleId,"tagList",n)) q:n=""  d
 . s tag=^conduitArticles("byId",articleId,"tagList",n)
 . k ^conduitArticles("byTag",tag,articleId)
 ; delete any associated comment records
 s commentId=""
 f  s commentid=$o(^conduitArticles("byId",articleId,"comments",commentId)) q:commentId=""  d
 . i $$del^conduitComments(commentid,0)
 ; finally, delete article record
 k ^conduitArticles("byId",articleId)
 QUIT 1
 ;
getTags(tags) ;
 ;
 n count,max,no,stop,tag,tagsByCount
 ;
 s max=100
 k tags
 ; count how many instances for each tag
 ; and store temporarily by frequency 
 s tag=""
 f  s tag=$o(^conduitArticles("byTag",tag)) q:tag=""  d
 . n id
 . s count=0
 . s id=""
 . f  s id=$o(^conduitArticles("byTag",tag,id)) q:id=""  d
 . . s count=count+1
 . ;
 . s tagsByCount(count,tag)=""
 ;
 ; now go through temp array in reverse to get the
 ; most frequent tags first.  Only return up
 ; to the max required no of tags
 s stop=0
 s no=0
 s count=""
 f  s count=$o(tagsByCount(count),-1) q:stop  q:count=""  d
 . s tag=""
 . f  s tag=$o(tagsByCount(count,tag)) q:stop  q:tag=""  d
 . . s no=no+1
 . . i no'>max d
 . . . n i
 . . . s i=$increment(tags)
 . . . s tags(i)=tag
 . . e  d
 . . . s stop=1
 ;
 QUIT 1
 ;
getIdBySlug(slug) ;
 ;
 QUIT $g(^conduitArticles("bySlug",slug))
 ;
getFeed(userId,offset,max,articles) ;
 ;
 n allFound,count,followsId,skipped,total,ts
 ;
 k ^conduitTemp($j)
 ;
 s total=0
 s allFound=0
 s skipped=0
 s count=0
 s followsId=""
 f  s followsId=$o(^conduitUsers("byId",userId,"follows",followsId)) q:followsId=""  d
 . n articleId
 . s articleId=""
 . f  s articleId=$o(^conduitArticles("byAuthor",followsId,articleId)) q:articleId=""  d
 . . s total=total+1
 . . i 'allFound d
 . . . i offset>0,skipped<offset d
 . . . . s skipped=skipped+1
 . . . e  d
 . . . . s ts=^conduitArticles("byId",articleId,"timestampindex")
 . . . . s ^conduitTemp($j,ts)=articleId
 . . . . s count=count+1
 . . . . i count=max d
 . . . . . s allFound=1
 ;
 ; now spin through the temporary document to pull out articles latest first
 ;
 k articles
 ;
 s ts=""
 f  s ts=$o(^conduitTemp($j,ts)) q:ts=""  d
 . n article,articleId,id
 . s id=$increment(articles)
 . s articleId=^conduitTemp($j,ts)
 . i $$get(articleId,userId,.article)
 . m articles(id)=article
 ;
 k ^conduitTemp($j)
 ;
 QUIT total
 ;
get(articleId,byUserId,article) ;
 ;
 n author,profile
 ;
 k article
 m article=^conduitArticles("byId",articleId)
 k article("timestampindex")
 k article("comments")
 s article("favorited")=$$favorited^conduitUsers(byUserId,articleId)
 s author=article("author")
 k article("author")
 i $$getProfile^conduitUsers(author,byUserId,.profile)
 m article("author")=profile
 ;
 QUIT 1
 ;
byAuthor(username,byUserId,offset,max,results) ;
 ;
 n allFound,articleId,articles,count,skipped,total,ts,userId
 ;
 k results
 ;
 s userId=$$idByUsername^conduitUsers(username)
 i userId="" d  QUIT -1
 . s articles("error")="notFound"
 ;
 k ^conduitTemp($j)
 ;
 s total=0
 s allFound=0
 s skipped=0
 s count=0
 s articleId=""
 f  s articleId=$o(^conduitArticles("byAuthor",userId,articleId)) q:articleId=""  d
 . s total=total+1
 . i 'allFound d
 . . i offset>0,skipped<offset d
 . . . s skipped=skipped+1
 . . e  d
 . . . s ts=^conduitArticles("byId",articleId,"timestampindex")
 . . . s ^conduitTemp($j,ts)=articleId
 . . . s count=count+1
 . . . i count=max s allFound=1
 ;
 ; now spin through the temporary document to pull out articles latest first
 ;
 k articles
 ;
 s ts=""
 f  s ts=$o(^conduitTemp($j,ts)) q:ts=""  d
 . s ^articles("o",ts)=""
 . n article,articleId,id
 . s id=$increment(articles)
 . s articleId=^conduitTemp($j,ts)
 . i $$get(articleId,byUserId,.article)
 . m articles(id)=article
 ;
 k ^conduitTemp($j)
 m results("articles")=articles
 s results("articlesCount")=total
 ;
 QUIT total
 ;
byTag(tag,byUserId,offset,max,results) ;
 ;
 n allFound,articleId,articles,count,skipped,total,ts
 ;
 k results
 k ^conduitTemp($j)
 ;
 s total=0
 s allFound=0
 s skipped=0
 s count=0
 s articleId=""
 f  s articleId=$o(^conduitArticles("byTag",tag,articleId)) q:articleId=""  d
 . s total=total+1
 . i 'allFound d
 . . i offset>0,skipped<offset d
 . . . s skipped=skipped+1
 . . e  d
 . . . s ts=^conduitArticles("byId",articleId,"timestampindex")
 . . . s ^conduitTemp($j,ts)=articleId
 . . . s count=count+1
 . . . i count=max s allFound=1
 ;
 ; now spin through the temporary document to pull out articles latest first
 ;
 k articles
 ;
 s ts=""
 f  s ts=$o(^conduitTemp($j,ts)) q:ts=""  d
 . n article,articleId,id
 . s id=$increment(articles)
 . s articleId=^conduitTemp($j,ts)
 . i $$get(articleId,byUserId,.article)
 . m articles(id)=article
 ;
 k ^conduitTemp($j)
 m results("articles")=articles
 s results("articlesCount")=total
 ;
 QUIT total
 ;
favoritedBy(username,byUserId,offset,max,results) ;
 ;
 n allFound,articleId,articles,count,skipped,total,ts,userId
 ;
 k results
 k ^conduitTemp($j)
 ;
 s userId=$$idByUsername^conduitUsers(username)
 i userId="" d  QUIT -1
 . s articles("error")="notFound"
 ;
 s total=0
 s allFound=0
 s skipped=0
 s count=0
 s articleId=""
 f  s articleId=$o(^conduitUsers("byId",userId,"favorited",articleId)) q:articleId=""  d
 . i $d(^conduitArticles("byId",articleId)) d
 . . s total=total+1
 . . i 'allFound d
 . . . i offset>0,skipped<offset d
 . . . . s skipped=skipped+1
 . . . e  d
 . . . . s ts=^conduitArticles("byId",articleId,"timestampindex")
 . . . . s ^conduitTemp($j,ts)=articleId
 . . . . s count=count+1
 . . . . i count=max s allFound=1
 ;
 ; now spin through the temporary document to pull out articles latest first
 ;
 k articles
 ;
 s ts=""
 f  s ts=$o(^conduitTemp($j,ts)) q:ts=""  d
 . n article,articleId,id
 . s id=$increment(articles)
 . s articleId=^conduitTemp($j,ts)
 . i $$get(articleId,byUserId,.article)
 . m articles(id)=article
 ;
 k ^conduitTemp($j)
 m results("articles")=articles
 s results("articlesCount")=total
 ;
 QUIT total
 ;
latest(byUserId,offset,max,results) ;
 ;
 n allFound,articles,count,skipped,total,ts
 ;
 s skipped=0
 s count=0
 s total=0
 s allFound=0
 ;
 k results
 ;
 s ts=""
 f  s ts=$o(^conduitArticles("byTimestamp",ts)) q:ts=""  d
 . s total=total+1
 . i 'allFound d
 . . i offset>0,skipped<offset d
 . . . s skipped=skipped+1
 . . e  d
 . . . n article,articleId
 . . . s articleId=$g(^conduitArticles("byTimestamp",ts))
 . . . i $$get(articleId,byUserId,.article)
 . . . s id=$increment(articles)
 . . . m articles(id)=article
 . . . s count=count+1
 . . . i count=max s allFound=1
 ;
 m results("articles")=articles
 s results("articlesCount")=total
 QUIT total
 ;
update(articleId,userId,newData) ;
 ;
 n article,currentSlug,currentTitle,n,newTitle,tag,timestamp,ts
 ;
 m article=^conduitArticles("byId",articleId)
 ;
 s currentTitle=$g(article("title"))
 s currentSlug=$g(article("slug"))
 s newTitle=$g(newData("title"))
 ;
 i newTitle'="",newTitle'=currentTitle d
 . ; remove the old slug index
 . k ^conduitArticles("bySlug",currentSlug)
 . ; create and index the new slug
 . s newSlug=$$createSlug(newTitle,articleId)
 . s ^conduitArticles("bySlug",newSlug)=articleId
 . s article("slug")=newSlug
 . s article("title")=newTitle
 ;
 i $d(newData("description")) d
 . s article("description")=newData("description")
 i $d(newData("body")) d
 . s article("body")=newData("body")
 s article("updatedAt")=$$UTCDateTime^%zmgwebUtils($h)
 s ts=article("timestampindex")
 k ^conduitArticles("byTimestamp",ts)
 i $$getTimeStamp(.timestamp)
 s ts=timestamp("ts")
 s ^conduitArticles("byTimestamp",ts)=articleId
 s article("timestampindex")=ts
 ;
 ; update tags
 ;
 ; first remove all the tags from the data record
 ; and remove from the corresponding index
 ;
 s n=""
 f  s n=$o(^conduitArticles("byId",articleId,"tagList",n)) q:n=""  d
 . s tag=^conduitArticles("byId",articleId,"tagList",n)
 . k ^conduitArticles("byTag",tag,articleId)
 k ^conduitArticles("byId",articleId,"tagList")
 ; 
 ; now update tags in article and create new taglist index
 ;
 k article("tagList")
 m article("tagList")=newData("tagList")
 s n=""
 f  s n=$o(newData("tagList",n)) q:n=""  d
 . s tag=newData("tagList",n)
 . s ^conduitArticles("byTag",tag,articleId)=articleId
 ;
 ; update main article database record
 ;
 m ^conduitArticles("byId",articleId)=article
 ;
 QUIT 1
 ;
rebuildIndices() ;
 ;
 n count,id
 ;
 k ^conduitArticles("byAuthor")
 k ^conduitArticles("bySlug")
 k ^conduitArticles("byTag")
 k ^conduitArticles("byTimestamp")
 ;
 s count=0
 s id=""
 f  s id=$o(^conduitArticles("byId",id)) q:id=""  d
 . n article,n,tag
 . s count=count+1
 . m article=^conduitArticles("byId",id)
 . s ^conduitArticles("byAuthor",article("author"),id)=id
 . s ^conduitArticles("bySlug",article("slug"))=id
 . s ^conduitArticles("byTimestamp",article("timestampindex"))=id
 . s n=""
 . s n=$o(article("tagList",n)) q:n=""  d
 . . s tag=article("tagList",n)
 . . s ^conduitArticles("byTag",tag,id)=id
 ;
 QUIT count
 ;
