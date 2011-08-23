import oauth
import httplib
import os, sys
import pickle
import unicodedata
import re
import xml.sax.saxutils
import json

consumer_key="change_this"
consumer_secret="change_this"
oauth_token="change_this"
oauth_token_secret="change_this"

#OAuth function
def oauth_req(url, key, secret, http_method="GET", post_body=None,
        http_headers=None):
    consumer = oauth.Consumer(key=consumer_key, secret=consumer_secret)
    token = oauth.Token(key=key, secret=secret)
    client = oauth.Client(consumer, token)
 
    resp, content = client.request(
        url,
        method=http_method,
        body=post_body,
        headers=http_headers,
    )
    return content


try:
    f = open("data.txt", "r") 
except IOError:
    f = open("data.txt", "w") 
    info = {'ace':'',
	    'segsw':'',
	    'ln':'',
            'pmeic':'',
            'ebt':''}
    pickle.dump(info,f)
    f.close()
    f = open("data.txt", "r") 

info = pickle.load(f)
f.close()

urls = {
   "ace":"/external/announcementsRSS.do?announcementBoardId=1174979",
   "segsw":"/external/announcementsRSS.do?announcementBoardId=1173111",
   "ln":"/external/announcementsRSS.do?announcementBoardId=1174262", 
   "pmeic":"/external/announcementsRSS.do?announcementBoardId=1173890",
   "ebt":"/external/announcementsRSS.do?announcementBoardId=1174691"
}

actual_info = ""

#main loop, for each url WARNING: some ugly hacks incoming for the HTML parsing
for course in urls:
    http = httplib.HTTPSConnection('fenix.ist.utl.pt', '443')
    http.request('GET',urls[course])
    response = http.getresponse()
    data = response.read().decode('ISO-8859-1')	
    actual_info = unicodedata.normalize('NFKD',data).encode('utf-8')
    title = re.split('<title>(.*)</title>',actual_info)
    title = title[len(title)-2]
    re.sub('\n','',title)
    link = re.split('<link>([^<]*)</link>',actual_info)
    link = link[len(link)-2]
    link = xml.sax.saxutils.unescape(link)
    description = re.split('<description>(.*)',actual_info)
    desc = ''
    for s in description[1:]:
	tmp = xml.sax.saxutils.unescape(s.split('</description>')[0])
	desc = desc + " " +tmp.split('>')[1].split('<')[0]
    re.sub('<[^>]*>','',desc)
    re.sub('\n','',desc)
    if info[course] != title:
    	info[course] = title
   	if link != '' and 'fenix.ist.utl.pt' in link:
		sapo = httplib.HTTPConnection('services.sapo.pt')
		sapo.request('GET','/PunyURL/GetCompressedURLByURLJSON?url='+link)
		jsonobj = json.loads(sapo.getresponse().read())
		link = jsonobj['punyURL']['ascii']
		limit = 140 - (4 + 3 + len(title) + len(link))   
		desc = desc.decode('utf-8') 
		response = oauth_req(
 		 'http://api.twitter.com/1/statuses/update.xml',
 		 oauth_token,
 		 oauth_token_secret,
 		 "POST",
 		 "status="+course.upper()+ " "+title+" "+desc[0:limit].encode('utf-8')+" "+link.encode('utf-8')
		)
