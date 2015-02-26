require 'uri'
require 'unirest'

module RemoteAsset
  class Generator < Jekyll::Generator
    REQUEST_TOKEN_URL = "https://api.dropbox.com/1/oauth/request_token"
    ACCESS_TOKEN_URL = "https://api.dropbox.com/1/oauth/access_token"
    FILES_PUT_URL = "https://api-content.dropbox.com/1/files_put/auto/"
    SHARES_URL = "https://api.dropbox.com/1/shares/auto/"

    def config_oauth(site)
      @config = {}
      config_file = ".remote_assets_config"
      if not File.exist?(config_file)
          puts "1. Please enter your app key. "
          @config[:app_key] = $stdin.gets.strip

          puts "2. Please enter your app secret. "
          @config[:app_secret] = $stdin.gets.strip

          response = Unirest.post REQUEST_TOKEN_URL,
            headers: { "Authorization" => build_oauth1_header(@config[:app_key], @config[:app_secret]) }

          request_tokens = CGI::parse(response.body)

          puts "3. Visit https://www.dropbox.com/1/oauth/authorize?oauth_token=#{ request_tokens['oauth_token'][0] } and approve this app. Press enter when finished."
          $stdin.gets

          response = Unirest.post ACCESS_TOKEN_URL,
            headers: {"Authorization" => build_oauth1_header(@config[:app_key], @config[:app_secret], request_tokens['oauth_token'][0], request_tokens['oauth_token_secret'][0]) }

          access_tokens = CGI::parse(response.body)

          @config[:access_token] = access_tokens['oauth_token'][0]
          @config[:access_token_secret] =  access_tokens['oauth_token_secret'][0]

          File.open(config_file, 'w+') do |f|
            YAML.dump(@config, f)
          end
      else
        File.open(config_file) do |f|
          @config = YAML.load_file(f)
        end
      end
    end

    def nonce(size = 7)
      Base64.encode64(OpenSSL::Random.random_bytes(size)).gsub(/\W/, '')
    end

    def build_oauth1_header(app_key, app_secret, token=nil, token_secret=nil)
      header_params = {
        oauth_version: "1.0",
        oauth_consumer_key: app_key,
        oauth_signature_method: "PLAINTEXT",
        oauth_token: token,
        oauth_signature: "#{ app_secret }&#{ token_secret }"
      }

      result = header_params.map do |k, v|
        "#{ k }=\"#{ v }\"" if v
      end

      return "OAuth #{ result.compact.join ', ' }"
    end

    def generate(site)
      config_oauth(site)
      
      files = Dir.glob("_assets/**/*") do |filename|
        # begin
          name = filename[filename.index('/')..-1]
          puts name
          File.open(filename) do |f|
            # upload the file
            response = Unirest.put FILES_PUT_URL + name,
              headers: {"Authorization" => build_oauth1_header(@config[:app_key], @config[:app_secret], @config[:access_token], @config[:access_token_secret]),
                        "Content-Length" => File::size(f),
                        "Content-Type" => "text/plain"},
              parameters: f

            # retrieve the url
            response = Unirest.post SHARES_URL + name,
              headers: {"Authorization" => build_oauth1_header(@config[:app_key], @config[:app_secret], @config[:access_token], @config[:access_token_secret])},
              parameters: {short_url: false}

            uri = URI(response.body["url"])
            site.remote_assets[name[1..-1]] =  "http://dl.dropboxusercontent.com#{ uri.path }"
          end
        # rescue
         # puts 'Error'
       # end

       puts site.remote_assets
     end
   end
 end
end
