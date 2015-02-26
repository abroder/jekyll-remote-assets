module Jekyll
  module RemoteAssetsPlugin
    module SitePatch
      def remote_assets
        @remote_assets ||= {}
      end
    end
  end
end

Jekyll::Site.send :include, Jekyll::RemoteAssetsPlugin::SitePatch