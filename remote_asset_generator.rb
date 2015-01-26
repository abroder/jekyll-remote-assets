require 'dropbox_sdk'
require 'uri'

module RemoteAsset
    class Generator < Jekyll::Generator
        def generate(site)
            flow = DropboxOAuth2FlowNoRedirect.new(site.config["remote_assets"]["app_key"], site.config["remote_assets"]["app_secret"])
            authorize_url = flow.start

            puts '1. Go to: ' + authorize_url
            puts '2. Click "Allow" (you might have to log in first)'
            puts '3. Copy the authorization code'
            print 'Enter the authorization code here: '
            code = gets.strip

            access_token, user_id = flow.finish(code)

            client = DropboxClient.new(access_token)
            session = DropboxOAuth2Session.new(access_token, nil)
            
            files = Dir.glob("_assets/**/*") do |e|
                begin
                    name = e[e.index('/')..-1]
                    file = client.put_file(name, open(e)) if File.file?(e)
                    response = session.do_get "/shares/auto/#{client.format_path(file['path'])}", {"short_url"=>false}
                    response = Dropbox::parse_response(response)
                    uri = URI(response["url"])
                    site.remote_assets[name[1..-1]] =  "http://dl.dropboxusercontent.com#{ uri.path }"
                rescue
                   puts 'Error'
                end
            end
        end
    end
end
