# frozen_string_literal: true

desc "Install project dependencies"
task :setup do
  sh "bundle install"
  sh "npm install"
end

desc "Run linter and type checks"
task :check do
  sh "rubocop"
  sh "rbs-inline --output lib"
  sh "rbs validate"
end

desc "Generate HTML from Markdown"
task build: [:check] do
  sh "ruby bin/convert.rb"
  sh "npm run build"
end

desc "Start the preview server"
task :server do
  sh "npm run preview -- --background"
end

task default: :setup
