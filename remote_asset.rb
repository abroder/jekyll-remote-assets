require 'dropbox_sdk'

module Jekyll
    class RemoteAssetTag < Liquid::Tag
        def initialize(tag_name, asset_name, tokens) 
            super
            @asset_name = asset_name.strip
        end

        def render(context)
        	puts "#{ @asset_name  == context.registers[:site].remote_assets.keys[0]}"
        	puts "#{ context.registers[:site].remote_assets }"
        	puts "#{ context.registers[:site].remote_assets[@asset_name] }"
            "#{ context.registers[:site].remote_assets[@asset_name] }"
        end
    end
end

Liquid::Template.register_tag('asset', Jekyll::RemoteAssetTag)