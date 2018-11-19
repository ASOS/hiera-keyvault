require 'puppetlabs_spec_helper/rake_tasks'

desc 'Validate files'
task :validate do
  Dir['spec/**/*.rb', 'lib/**/*.rb'].each do |ruby_file|
    sh "ruby -c #{ruby_file}" unless ruby_file =~ %r{spec/fixtures}
  end
end

desc 'Run lint, validate, and spec tests.'
task :test do
  [:lint, :validate].each do |test|
    Rake::Task[test].invoke
  end
end
