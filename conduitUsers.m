conduitUsers ; Conduit Users Database functions
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
 ; 2 December 2020
 ;
getTimeStamp(results) ;
 ;
 n iso,now,ts
 ;
 k results
 s now=$$now^%zmgwebUtils()
 s iso=$$UTCDateTime^%zmgwebUtils(now)
 ; get reverse chronological index timestamp value
 s ts=100000000000000-$$epochTime^%zmgwebUtils(now)
 s results("iso")=iso
 s results("ts")=ts
 QUIT 1
 ;
 ; ==========================
 ;
exists(id) ;
 QUIT $d(^conduitUsers("byId",id))
 ;
emailExists(email) ;
 QUIT $d(^conduitUsers("byEmail",email))
 ;
getEmail(id) ;
 QUIT $g(^conduitUsers("byId",id,"email"))
 ;
changeEmail(id,newEmail) ;
 ;
 n oldEmail
 ;
 s oldEmail=$$getEmail(id)
 k ^conduitUsers("byEmail",oldEmail)
 s ^conduitUsers("byEmail",newEmail)=id
 s ^conduitUsers("byId",id,"email")=newEmail
 QUIT 1
 ;
usernameExists(username) ;
 QUIT $d(^conduitUsers("byUsername",username))
 ;
idByUsername(username) ;
 QUIT $g(^conduitUsers("byUsername",username))
 ;
changeUsername(id,newUsername) ;
 ;
 k ^conduitUsers("byUsername",$$getUsername(id))
 s ^conduitUsers("byUsername",newUsername)=id
 s ^conduitUsers("byId",id,"username")=newUsername
 ;
 QUIT 1
 ;
getUsername(id) ;
 QUIT $g(^conduitUsers("byId",id,"username"))
 ;
idByEmail(email) ;
 QUIT $g(^conduitUsers("byEmail",email))
 ;
authenticate(email,password) ;
 n ok
 i $$emailExists(email) d  QUIT ok
 . n hash,id
 . s id=$$idByEmail(email)
 . s hash=$g(^conduitUsers("byId",id,"password"))
 . s ok=$$verifyPassword^%zmgwebUtils(password,hash)
 QUIT 0
 ;
get(id,user) ;
 ;
 k user
 ;
 m user=^conduitUsers("byId",id)
 QUIT $d(user)
 ;
getNextId() ;
 QUIT $increment(^conduitUsers("nextId"))
 ;
create(user) ;
 ;
 ;    user: {
 ;      username,
 ;      email,
 ;      password
 ;    }
 ;
 n hash,id,now,password
 ;
 s id=$$getNextId()
 s user("id")=id
 s now=$$UTCDateTime^%zmgwebUtils($$now^%zmgwebUtils()) 
 s user("createdAt")=now
 s user("updatedAt")=now
 s password=$g(user("password"))
 s hash=$$hashPassword^%zmgwebUtils(password)
 s user("password")=hash
 s user("bio")=""
 s user("image")=""
 ;
 m ^conduitUsers("byId",id)=user
 s ^conduitUsers("byUsername",user("username"))=id
 s ^conduitUsers("byEmail",user("email"))=id
 ;
 QUIT id
 ;
update(id,newData) ;
 ;
 n ok
 ;
 i '$$exists(id) QUIT 0
 ;
 i $d(newData("email")) s ok=$$changeEmail(id,newData("email"))
 i $d(newData("username")) s ok=$$changeUsername(id,newData("username"))
 i $g(newData("password"))'="" d
 . s ^conduitUsers("byId",id,"password")=$$hashPassword^%zmgwebUtils(newData("password"))
 i $d(newData("image")) s ^conduitUsers("byId",id,"image")=newData("image")
 i $d(newData("bio")) s ^conduitUsers("byId",id,"bio")=newData("bio")
 s ^conduitUsers("byId",id,"updatedAt")=$$UTCDateTime^%zmgwebUtils($$now^%zmgwebUtils()) 
 ;
 QUIT 1
 ;
favorited(userId,articleId) ;
 ;
 n favorited
 ;
 s favorited="false"
 ;
 i userId=""!(articleId="") QUIT favorited
 i $d(^conduitUsers("byId",userId,"favorited",articleId)) s favorited="true"
 QUIT favorited
 ;
favorite(userId,articleId) ;
 s ^conduitUsers("byId",userId,"favorited",articleId)=articleId
 i $increment(^conduitArticles("byId",articleId,"favoritesCount"))
 QUIT 1
 ;
unfavorite(userId,articleId) ;
 ;
 n count
 ;
 k ^conduitUsers("byId",userId,"favorited",articleId)
 s count=+$g(^conduitArticles("byId",articleId,"favoritesCount"))
 s count=count-1
 i count<0 s count=0
 s ^conduitArticles("byId",articleId,"favoritesCount")=count
 QUIT 1
 ;
getProfile(ofUserId,byUserId,profile) ;
 ;
 n x
 ;
 k profile
 ;
 i '$d(^conduitUsers("byId",ofUserId)) d  QUIT 0
 . s profile("error")="User whose profile is being requested does not exist"
 ;
 i $g(byUserId)'="",'$d(^conduitUsers("byId",byUserId)) d  QUIT 0
 . s profile("error")="User requesting profile does not exist"
 ;
 s profile("username")=$g(^conduitUsers("byId",ofUserId,"username"))
 s profile("bio")=$g(^conduitUsers("byId",ofUserId,"bio"))
 s profile("image")=$g(^conduitUsers("byId",ofUserId,"image"))
 s profile("following")="false"
 i $g(byUserId)'="",$d(^conduitUsers("byId",byUserId,"follows",ofUserId)) d
 . s profile("following")="true"
 QUIT 1
 ;
follows(userId,usernameToFollow) ;
 ;
 n idToFollow
 ;
 s idToFollow=$$idByUsername(usernameToFollow)
 QUIT $d(^conduitUsers("byId",userId,"follows",idToFollow))
 ;
follow(userId,usernameToFollow,profile) ;
 ;
 n idToFollow
 ;
 s idToFollow=$$idByUsername(usernameToFollow)
 s ^conduitUsers("byId",userId,"follows",idToFollow)=idToFollow
 i $$getProfile(idToFollow,userId,.profile)
 QUIT 1
 ;
unfollow(userId,usernameToUnfollow,profile) ;
 ;
 n idToUnfollow
 ;
 s idToUnfollow=$$idByUsername(usernameToUnfollow)
 k ^conduitUsers("byId",userId,"follows",idToUnfollow)
 i $$getProfile(idToUnfollow,userId,.profile)
 QUIT 1
 ;
