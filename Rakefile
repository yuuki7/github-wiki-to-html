# frozen_string_literal: true

require 'yard'

desc 'Install project dependencies'
task :setup do
  sh 'bundle install'
  sh 'rbs --collection .config/rbs_collection.yaml collection install'
  sh 'npm install'
end

desc 'Run linter and type checks'
task :check do
  sh 'rubocop --config .config/.rubocop.yaml'
  sh 'rbs-inline --output lib'
  sh 'rbs validate'
  sh 'steep check --steepfile .config/Steepfile'
end

desc 'Generate HTML from Markdown'
task build: [:check] do
  sh 'ruby bin/convert.rb'
  sh 'npm run build'
end

desc 'Start the preview server'
task :server do
  sh 'npm run preview -- --background'
end

ENV['OPTS'] = '--yardopts .config/.yardopts'

YARD::Rake::YardocTask.new

desc 'Start YARD documentation server'
task 'yard:server' do
  sh 'yard server --reload'
end

task default: :setup
