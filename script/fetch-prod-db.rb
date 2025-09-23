#!/usr/bin/env ruby
require "tmpdir"
require "fileutils"
require "open3"

if ARGV.size != 1
  warn "Usage: #{$PROGRAM_NAME} TENANT_ID"
  exit 1
end

tenant_id = ARGV[0]
CONTAINER = "fizzy-web-production-b2f4038ea1fd054e313308940d9e445428f35b23"
REMOTE_PATH = "/rails/storage/tenants/production/#{tenant_id}/db/main.sqlite3.1"

Dir.mktmpdir do |tmpdir|
  local_file = File.join(tmpdir, "main.sqlite3")

  puts "→ Copying #{REMOTE_PATH} from container to #{local_file}"
  cmd = %(ssh app@fizzy-app-101 "docker cp #{CONTAINER}:#{REMOTE_PATH} -" | tar -xOf - > #{local_file})
  system(cmd) or abort("Failed to copy database file")

  puts "→ Running script/load-prod-db-in-dev.rb with #{local_file}"
  exec("bundle", "exec", "ruby", "script/load-prod-db-in-dev.rb", local_file)
end
