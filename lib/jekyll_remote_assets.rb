require 'uri'
require 'unirest'
require 'set'

module Jekyll
  module RemoteAsset

    module SitePatch
      def remote_assets
        @remote_assets ||= {}
      end
    end

    Jekyll::Site.send :include, Jekyll::RemoteAsset::SitePatch

    class RemoteAssetTag < Liquid::Tag
      def initialize(tag_name, asset_name, tokens) 
        super
        @asset_name = asset_name.strip
      end

      def render(context)
        "#{ context.registers[:site].remote_assets[@asset_name] }"
      end
    end

    Liquid::Template.register_tag('asset', Jekyll::RemoteAsset::RemoteAssetTag)

    class Generator < Jekyll::Generator
      REQUEST_TOKEN_URL = "https://api.dropbox.com/1/oauth/request_token"
      ACCESS_TOKEN_URL = "https://api.dropbox.com/1/oauth/access_token"
      FILES_PUT_URL = "https://api-content.dropbox.com/1/files_put/auto"
      FILE_METADATA_URL = "https://api.dropbox.com/1/metadata/auto"
      SHARES_URL = "https://api.dropbox.com/1/shares/auto"

      def config_oauth(plugin_config)
        @oauth_config = {}
        config_file = plugin_config["config"]
        if not File.exist?(config_file)
          puts "1. Create a new application on the Dropbox App Console, if you haven't already: https://www.dropbox.com/developers/apps"
          $stdin.gets

          puts "2. Please enter your app key. "
          @oauth_config[:app_key] = $stdin.gets.strip

          puts "3. Please enter your app secret. "
          @oauth_config[:app_secret] = $stdin.gets.strip

          response = Unirest.post REQUEST_TOKEN_URL,
            headers: { "Authorization" => build_oauth1_header(@oauth_config[:app_key], @oauth_config[:app_secret]) }

          request_tokens = CGI::parse(response.body)

          puts "4. Visit https://www.dropbox.com/1/oauth/authorize?oauth_token=#{ request_tokens['oauth_token'][0] } and approve this app. Press enter when finished."
          $stdin.gets

          response = Unirest.post ACCESS_TOKEN_URL,
            headers: {"Authorization" => build_oauth1_header(@oauth_config[:app_key], @oauth_config[:app_secret], request_tokens['oauth_token'][0], request_tokens['oauth_token_secret'][0]) }

          access_tokens = CGI::parse(response.body)

          @oauth_config[:access_token] = access_tokens['oauth_token'][0]
          @oauth_config[:access_token_secret] =  access_tokens['oauth_token_secret'][0]

          File.open(config_file, 'w+') do |f|
            YAML.dump(@oauth_config, f)
          end
        else
          File.open(config_file) do |f|
            @oauth_config = YAML.load_file(f)
          end
        end
      end

      def init_cache(plugin_config)
        @cache = {}
        cache_file = plugin_config["cache"]

        # TODO: fix first-time set up of cache
        if not File.exist?(cache_file)
          File.open(cache_file, 'w+') do |f|
            YAML.dump(@cache, f)
          end
        end

        File.open(cache_file) do |f|
          @cache = YAML.load_file(f)
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
        plugin_config = site.config["remote_assets"] || {}
        plugin_config["config"] ||= site.source + "/.remote_assets_config"
        plugin_config["cache"] ||= site.source  + "/.remote_assets_cache"

        config_oauth(plugin_config)
        init_cache(plugin_config)

        file_set = Set.new

        Dir.glob("_assets/**/*") do |filename|
          begin
            next if File.directory?(filename)

            name = filename[filename.index('/')..-1]
            overwrite = plugin_config['overwrite'] || true

            File.open(filename) do |f|
              file_set.add filename

              md5 = Digest::MD5.file(filename).hexdigest
              if @cache[filename] and @cache[filename][:md5] == md5
                # if it's cached, make sure the file is still in the Dropbox drive
                response = Unirest.get FILE_METADATA_URL + name,
                  headers: {"Authorization" => build_oauth1_header(@oauth_config[:app_key], @oauth_config[:app_secret], @oauth_config[:access_token], @oauth_config[:access_token_secret])}

                if response.body["error"] == nil && !response.body["is_deleted"]
                  site.remote_assets[name[1..name.length]] = @cache[filename][:url]
                  next
                end
              end

              # upload the file
              response = Unirest.put FILES_PUT_URL + name + "?overwrite=#{ overwrite }",
                headers: {"Authorization" => build_oauth1_header(@oauth_config[:app_key], @oauth_config[:app_secret], @oauth_config[:access_token], @oauth_config[:access_token_secret]),
                          "Content-Length" => File::size(f),
                          "Content-Type" => "text/plain"},
                parameters: f

              # retrieve the url
              response = Unirest.post SHARES_URL + name,
                headers: {"Authorization" => build_oauth1_header(@oauth_config[:app_key], @oauth_config[:app_secret], @oauth_config[:access_token], @oauth_config[:access_token_secret])},
                parameters: {short_url: false}

              uri = URI(response.body["url"])
              site.remote_assets[name[1..-1]] =  "http://dl.dropboxusercontent.com#{ uri.path }"
              
              @cache[filename] = { md5: md5, url: "http://dl.dropboxusercontent.com#{ uri.path }"}
            end
          rescue
            puts "Error uploading #{ filename }"
          end
        end
        @cache.delete_if { |key, value| not file_set.include? key }

        File.open(plugin_config["cache"], 'w+') do |f|
          YAML.dump(@cache, f)
        end
      end
    end

  end
end
