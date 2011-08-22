require 'net/https'
require 'cgi.rb'
require 'base64'
require 'iconv'
require 'oauth'

@consumer_key="change_this"
@consumer_secret="change_this"
oauth_token="change_this"
oauth_token_secret="change_this"


#OAuth function
def prepare_access_token(oauth_token, oauth_token_secret)
  consumer = OAuth::Consumer.new(@consumer_key, @consumer_secret,
    { :site => "http://api.twitter.com",
      :scheme => :header
    })
  # now create the access token object from passed values
  token_hash = { :oauth_token => oauth_token,
                 :oauth_token_secret => oauth_token_secret
               }
  access_token = OAuth::AccessToken.from_hash(consumer, token_hash )
  return access_token
end


begin
   f = File.new("data.txt", "r") 
rescue Errno::ENOENT
   #File doesn't exists, fill it with sample data
   f = File.new("data.txt", "w")
   info = {
      "asa" => "",
      "es" => "",
      "mod" => "",
      "port" => "",
      "sd" => ""
   }
   Marshal.dump(info,f)
   f.close
   f = File.new("data.txt", "r")
end

info = Marshal.load(f)
f.close

urls = {
   "ace" => "/external/announcementsRSS.do?announcementBoardId=1174979",
   "segsw" => "/external/announcementsRSS.do?announcementBoardId=1173111",
   "ln" => "/external/announcementsRSS.do?announcementBoardId=1174262", 
   "pmeic" => "/external/announcementsRSS.do?announcementBoardId=1173890"
}


actual_info = ""
urls.each { |id,url|
   begin
      http = Net::HTTP.new('fenix.ist.utl.pt', '443') 
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.start do |http|
         request = Net::HTTP::Get.new(url)
         response = http.request(request)
         response.value
         actual_info = Iconv.conv("UTF-8", "ISO-8859-1", response.body)
      end

   rescue Net::HTTPExceptions
      next #do nothing if couldn't get feed, it'll in the near future
   end

   begin 
      title = actual_info.scan(/<title>(.*)<\/title>/)[1][0] 
      title = title.gsub(/\n/,'')
      link = CGI.unescapeHTML(actual_info.scan(/<link>([^<]*)<\/link>/)[0][0]) 
      # Terrible Hack Incoming
      # reason: to avoid using an xml parser... as we only want the first description on the
      # file this should work
      desc = actual_info.scan(/<description>(.*)/m)[0][0].split("</description>")[0] 
      desc = CGI.unescapeHTML(desc)
      desc = desc.gsub(/<[^>]*>/, '') #delete html and new lines
      desc = desc.gsub(/\n/, '') #delete html and new lines
   rescue NoMethodError
      title = ""
      link = ""
      desc = ""
   end


   if info[id] != title
      info[id] = title


      #connect to sapo puny and compreess the link

      if link != ""
         link = CGI.escape(link)
         begin
            http = Net::HTTP.new("puny.sapo.pt")
            http.start do http
               request = Net::HTTP::Get.new("/punify?html=0&url=#{link}")
               response = http.request request
               link = "http://" + Base64::decode64(response['location'].scan(/&puny=([^&]*)&/)[0][0])
            end
         rescue Net::HTTPExceptions 
            link = "" #forget the link
         end
      end

      limit = 140 - (4 + 3 + title.length + link.length)
      access_token = prepare_access_token(oauth_token, oauth_token_secret)
      response = access_token.request(:post, "http://api.twitter.com/1/statuses/update.xml", {"Content-Type" => "application/xml", "status" =>id.upcase+" "+title+" "+desc.slice(0,limit) + " " + link.force_encoding('utf-8') })
         
   end
}

f = File.new("data.txt", "w")
Marshal.dump(info,f)
f.close
