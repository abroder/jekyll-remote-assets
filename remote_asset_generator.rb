require 'uri'
require 'unirest'

module RemoteAsset
  class Generator < Jekyll::Generator
    def config_oauth
      @config = {}
      config_file = site.config[:remote_assets][:config] || ".remote_assets_config"
      if not File.exist?(config_file)
          puts "1. Please enter your app key. "
          @config[:app_key] = $stdin.gets.strip

          puts "2. Please enter your app secret. "
          @config[:app_secret] = $stdin.gets.strip

          response = Unirest.post REQUEST_TOKEN_URL,
            headers: { "Authorization" => build_oauth1_header(config[:app_key], config[:app_secret]) }

          request_tokens = CGI::parse(response.body)

          puts "3. Visit https://www.dropbox.com/1/oauth/authorize?oauth_token=#{ request_tokens['oauth_token'][0] } and approve this app. Press enter when finished."
          $stdin.gets

          response = Unirest.post ACCESS_TOKEN_URL,
            headers: {"Authorization" => build_oauth1_header(config[:app_key], config[:app_secret], request_tokens['oauth_token'][0], request_tokens['oauth_token_secret'][0]) }

          access_tokens = CGI::parse(response.body)

          @config[:access_token] = access_tokens['oauth_token'][0]
          @config[:access_token_secret] =  access_tokens['oauth_token_secret'][0]

          File.open(config_file, 'w+') do |f|
            YAML.dump(config, f)
          end
      else
        File.open(config_file) do |f|
          @config = YAML.load_file(f)
        end
      end

      config
    end

    def nonce(size = 7)
      Base64.encode64(OpenSSL::Random.random_bytes(size)).gsub(/\W/, '')
    end

    def build_oauth1_header(app_key, app_secret, token=nil, token_secret=nil)
      header_params = {
        oauth_version: "1.0",
        oauth_consumer_key: app_key,
        oauth_signature_method: "PLAINTEXT",
        oauth_token: token,g
        oauth_signature: "#{ app_secret }&#{ token_secret }"
      }

      result = header_params.map do |k, v|
        "#{ k }=\"#{ v }\"" if v
      end

      return "OAuth #{ result.compact.join ', ' }"
    end

    def generate(site)
      config_oauth
      
      files = Dir.glob("_assets/**/*") do |filename|
        begin
          name = e[e.index('/')..-1]
          File.open(name) do |f|
              response = Unirest.put FILES_PUT_URL + name,
                headers: {"Authorization" => build_oauth1_header(@config[:app_key], @config[:app_secret], @config[:access_token], @config[:access_token_secret]),
                          "Content-Length" => File::size(f),
                          "Content-Type" => "text/plain"},
                parameters: f

              puts response.body
          end

          # file = client.put_file(name, open(e), site.config["remote_assets"]["overwrite"]) if File.file?(e)
          # response = session.do_get "/shares/auto/#{client.format_path(file['path'])}", {"short_url"=>false}
          # response = Dropbox::parse_response(response)
          # uri = URI(response["url"])
          # site.remote_assets[name[1..-1]] =  "http://dl.dropboxusercontent.com#{ uri.path }"
        rescue
         puts 'Error'
       end
     end
   end
 end
end
