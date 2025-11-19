# frozen_string_literal: true

require_relative 'lib/pbf_reverse_geocoder/version'

Gem::Specification.new do |spec|
  spec.name = 'pbf_reverse_geocoder'
  spec.version = PbfReverseGeocoder::VERSION
  spec.authors = ['Keisuke Terada']
  spec.email = ['rorensu2236@gmail.com']

  spec.summary = 'PBF-based reverse geocoding library for Japanese administrative areas'
  spec.description = 'A lightweight reverse geocoding library that uses Mapbox Vector Tiles (PBF format) to find Japanese administrative areas (prefecture, city) from latitude/longitude coordinates. Ruby implementation of @geolonia/open-reverse-geocoder.'
  spec.homepage = 'https://github.com/keisuke2236/pbf_reverse_geocoder'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/keisuke2236/pbf_reverse_geocoder'
  spec.metadata['changelog_uri'] = 'https://github.com/keisuke2236/pbf_reverse_geocoder/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  # (現時点では標準ライブラリのみ使用)

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
end
