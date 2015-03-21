Gem::Specification.new do |s|
  s.name        = 'jekyll_remote_assets'
  s.version     = '0.1.0'
  s.date        = '2015-03-21'
  s.summary     = "Automatically upload static assets to Dropbox on site generation to save on server costs"
  s.authors     = ["Aaron Broder"]
  s.email       = 'aaronbroder@gmail.com'
  s.files       = ["lib/jekyll_remote_assets.rb"]
  s.homepage    =
    'https://github.com/abroder/jekyll-remote-assets'
  s.license       = 'MIT'
  s.add_runtime_dependency 'unirest', '~>1.1', '>= 1.1.2'
end
