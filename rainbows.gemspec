# -*- encoding: binary -*-
ENV["VERSION"] or abort "VERSION= must be specified"
manifest = File.readlines('.manifest').map! { |x| x.chomp! }
require 'wrongdoc'
extend Wrongdoc::Gemspec
name, summary, title = readme_metadata

Gem::Specification.new do |s|
  s.name = %q{rainbows}
  s.version = ENV["VERSION"].dup

  s.authors = ["#{name} hackers"]
  s.date = Time.now.utc.strftime('%Y-%m-%d')
  s.description = readme_description
  s.email = %q{rainbows-talk@rubyforge.org}
  s.executables = %w(rainbows)
  s.extra_rdoc_files = extra_rdoc_files(manifest)
  s.files = manifest
  s.homepage = Wrongdoc.config[:rdoc_url]
  s.summary = summary
  s.rdoc_options = rdoc_options
  s.rubyforge_project = %q{rainbows}

  # we want a newer Rack for a valid HeaderHash#each
  s.add_dependency(%q<rack>, ['~> 1.1'])

  # kgio 2.5 has kgio_wait_* methods that take optional timeout args
  s.add_dependency(%q<kgio>, ['~> 2.5'])

  # we need Unicorn for the HTTP parser and process management
  # 4.6.0+ supports hijacking, 4.6.2 fixes the chunk parser (for Ruby 2.0.0)
  s.add_dependency(%q<unicorn>, ["~> 4.6", ">= 4.6.2"])

  s.add_development_dependency(%q<isolate>, "~> 3.1")
  s.add_development_dependency(%q<wrongdoc>, "~> 1.6")

  # optional runtime dependencies depending on configuration
  # see t/test_isolate.rb for the exact versions we've tested with
  #
  # Revactor >= 0.1.5 includes UNIX domain socket support
  # s.add_dependency(%q<revactor>, [">= 0.1.5"])
  #
  # Revactor depends on Rev, too, 0.3.0 got the ability to attach IOs
  # s.add_dependency(%q<rev>, [">= 0.3.2"])
  #
  # Cool.io is the new Rev, but it doesn't work with Revactor
  # s.add_dependency(%q<cool.io>, [">= 1.0"])
  #
  # Rev depends on IOBuffer, which got faster in 0.1.3
  # s.add_dependency(%q<iobuffer>, [">= 0.1.3"])
  #
  # We use the new EM::attach/watch API in 0.12.10
  # s.add_dependency(%q<eventmachine>, ["~> 0.12.10"])
  #
  # NeverBlock, currently only available on http://gems.github.com/
  # s.add_dependency(%q<espace-neverblock>, ["~> 0.1.6.1"])

  # We inherited the Ruby 1.8 license from Mongrel, so we're stuck with it.
  # GPLv3 is preferred.
  s.licenses = ["GPLv2", "GPLv3", "Ruby 1.8"]
end
