# scroller_test

this is a flutter app für a scool project. it is meant to be used for any real-live uses, but all the used backend providers, storage providers and code structure are the optimal ones for their corrsponding usages.

## auth and main backend service
for authentification ive descided to use **firebase auth**. firebase is a service by google that provides practically free authentification. it is pretty safe, performant and allows you to sign in / sign up using your email / phone number or other third party services like google, github or discord. for this project ive descided to only use email and google sign in since those are the two most common ones. <br>
you can also use firebase for connecting other services like googles **ad mob**, an ad provider for android and ios that automatically choses the best ads and partners for you to get the maximum income. it also supports personized ads, however ive descided not tu use that since the main audience of this app would be minors and the law is prety limiting there.<br>
micro transactions using third party providers like **stripe** are alo posible to connect to firebase.
### why connect everything?
its really handy to see all your incomes in one place

## database provider
as for the database provider, ive descided to use **supabase**. supabase is a backend provider containing its own services like auth and third party connections, however ive descided to use firebase for that because of the reasons ive stated above.<br>
the database uses **postgreSQL**. it provides a lot of features like rls policies, views, relatively high performance, functions and a lot more. 

### why not just use firestore?
firestore is a db provider in firebase. although it is a lot easier to connect to other firebase services, it has a lot of limitations. <br>
firestore uses **noSql**. noSql is a sql dialect like postgreSql, that stores its data a bit differently. ther are no tables you can access and connect, but instead there are collections, documents, subcollections and more. so if you want to access a users following for example, you would do something like this (pseudo code):

    users/{userId}/following/
the corresponding postgreSql statement would be something like this:

    SELECT following_id FROM following WHERE follower = {userId}

while that does seem easy at first, youre very limited when you try to do more advanced postgeSql queries in noSql. for example something like this wouldnt be possible to do in a single noSql request:

    SELECT * from profiles p, videos v where p.id = {userId} INNER JOIN v.author_id ON p.id

### pricing 
pretty much the main reason why i chose supabase is the pricing. <br>
when using supabase, you only pay for some of the servers resources. (in the pro plan, per month) you pay for
- database size: 8 gb are included, after that 0.125$ / gb
- monthly active users: 100,000 MAU, then 0.00325$ / MAU
- egress (data transfer): 250 gb included, after that 0.09$ / gb
- base pro plan cost: 25$
<br>
while this seems expensive, you have to compare this to the size of the data thats actually stored. since we dont store the actual image / video data but just the urls, the file size of one video is about 200 bytes at max. so you would be able to store about 40 million videos without exceeding the included database size. 
as for the egress fees, the users would need to watch over 41 million videos every day to exceed the included egress.<br><br>
lets compare this to firestore.<br>
firestore bills differently. there you pay per read / write. a read counts as a returned entry by a query, a write counts for every updated entry.



