# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# Builds a minimal fixture git repository for testing, used when a full
# caller wiki is not available. Wraps the fixture in test/fixtures/wiki/
# and commits it into a git repo so Wiki#build and its siblings can run.
module FixtureWiki
  FIXTURE_DIR = File.expand_path('../../test/fixtures/wiki', __dir__) unless defined?(FIXTURE_DIR)

  module_function

  # Builds a fresh fixture wiki at `root`. Returns the root path.
  #
  # The sequence is committed with deterministic dates and authors for
  # repeatable assertions.
  def build(root)
    Dir.mkdir(root) unless File.directory?(root)
    seed_wiki(root)
  end

  # Seed `root` with fixture content and a single commit, skipping the
  # directory-creation boilerplate that callers already handled.
  def seed_wiki(root)
    cp_fixture_into(root)
    init_git(root)
    commit_all(root, message: 'seed fixture wiki', at: '2024-01-01T00:00:00Z')
  end

  def cp_fixture_into(root)
    FileUtils.cp_r(Dir.glob(File.join(FIXTURE_DIR, '*')), root)
  end

  def init_git(root)
    system('git', 'init', '-q', '--initial-branch=main', chdir: root) or raise 'git init failed'
    system('git', 'config', 'user.email', 'fixture@example.com', chdir: root)
    system('git', 'config', 'user.name', 'Fixture Bot', chdir: root)
  end

  def commit_all(root, message:, at: nil)
    system('git', 'add', '-A', chdir: root) or raise 'git add failed'
    env = at ? { 'GIT_AUTHOR_DATE' => at, 'GIT_COMMITTER_DATE' => at } : {}
    system(env, 'git', 'commit', '-qm', message, chdir: root) or raise 'git commit failed'
  end
end
