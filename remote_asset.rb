module Jekyll
    class RemoteAssetTag < Liquid::Tag
        def initialize(tag_name, asset_name, tokens) 
            super
            @asset_name = asset_name.strip
        end

        def render(context)
          puts context.registers[:site].remote_assets
          "#{ context.registers[:site].remote_assets[@asset_name] }"
        end
    end
end

Liquid::Template.register_tag('asset', Jekyll::RemoteAssetTag)