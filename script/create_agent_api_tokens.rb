#!/usr/bin/env ruby
# Script to create API tokens for Fizzy simulator agents
#
# Usage:
#   docker-compose exec app bin/rails runner script/create_agent_api_tokens.rb
#   OR
#   bin/rails runner script/create_agent_api_tokens.rb
#
# This script creates:
#   1. A unique Identity and User for each agent
#   2. API tokens for each agent
#   3. Board access for each agent to the specified boards
#
# Configuration:
#   - Set BOARD_ID to automatically use the board's account and grant access to that board (recommended)
#   - Set BOARD_IDS (array) to grant access to multiple boards
#   - Set ACCOUNT_ID to use a specific account by ID
#   - Set ACCOUNT_NAME to use a specific account by name
#   - Leave all nil to use the first account (may not be what you want!)
#
# Example:
#   BOARD_ID = "03f5sejxe37ggf14dmoxatppj"  # Will use the board's account and grant access
#   BOARD_IDS = ["03f5sejxe37ggf14dmoxatppj", "03f5sejxe37ggf14dmoxatppk"]  # Multiple boards

# Agent configurations - adjust these to match your simulator setup
AGENTS = [
  {
    email: "overcommitter@fizzy-sim.local",
    name: "The Overcommitter",
    role: "member"  # Valid roles: owner, admin, member, system
  },
  {
    email: "scope.creeper@fizzy-sim.local",
    name: "The Scope Creeper",
    role: "member"
  },
  {
    email: "perfectionist@fizzy-sim.local",
    name: "The Perfectionist",
    role: "member"
  },
  {
    email: "ghost@fizzy-sim.local",
    name: "The Ghost",
    role: "member"
  },
  {
    email: "bikeshedder@fizzy-sim.local",
    name: "The Bikeshedder",
    role: "member"
  },
  {
    email: "arsonist@fizzy-sim.local",
    name: "The Arsonist",
    role: "member"
  },
  {
    email: "lurker@fizzy-sim.local",
    name: "The Lurker",
    role: "member"
  },
  {
    email: "automator@fizzy-sim.local",
    name: "The Automator",
    role: "member"
  },
  {
    email: "archaeologist@fizzy-sim.local",
    name: "The Archaeologist",
    role: "member"
  },
  {
    email: "firefighter@fizzy-sim.local",
    name: "The Fire Fighter",
    role: "member"
  }
].freeze

def find_or_create_identity(email)
  identity = Identity.find_by(email_address: email)
  
  if identity
    puts "  → Found existing Identity: #{email}"
    return identity
  end
  
  identity = Identity.create!(
    email_address: email
  )
  
  puts "  ✓ Created Identity: #{email}"
  identity
end

def find_or_create_user(account, identity, name, role)
  user = User.find_by(account: account, identity: identity)
  
  if user
    puts "  → Found existing User: #{name} (ID: #{user.id})"
    # Update name if it changed (don't update role if user already exists to avoid errors)
    user.update!(name: name) if user.name != name
    return user
  end
  
  user = User.create!(
    account: account,
    identity: identity,
    name: name,
    role: role,
    active: true
  )
  
  puts "  ✓ Created User: #{name} (ID: #{user.id})"
  user
end

def create_api_token(account, user, name)
  token = ApiToken.find_by(account: account, user: user, name: "#{name} API Token")
  
  if token
    puts "  → API token already exists for #{name}"
    puts "     Token: #{token.token}"
    return token
  end
  
  token = ApiToken.create!(
    account: account,
    user: user,
    name: "#{name} API Token"
  )
  
  puts "  ✓ Created API token for #{name}"
  puts "     Token: #{token.token}"
  
  token
end

def grant_board_access(user, board, account)
  access = Access.find_by(user: user, board: board, account: account)
  
  if access
    puts "  → Board access already exists: #{board.name}"
    return access
  end
  
  access = Access.create!(
    user: user,
    board: board,
    account: account,
    involvement: "access_only" # "access_only" allows full access, "watching" is read-only
  )
  
  puts "  ✓ Granted board access: #{board.name}"
  access
end

# Configuration - adjust these as needed
# These can be overridden when loading the script:
#   BOARD_ID = "03f5sejxe37ggf14dmoxatppj"
#   load 'script/create_agent_api_tokens.rb'
ACCOUNT_ID = defined?(BOARD_ID) ? nil : nil  # Set to account ID or nil to use first account
ACCOUNT_NAME = nil # Set to account name (alternative to ACCOUNT_ID)
BOARD_ID = defined?(BOARD_ID) ? BOARD_ID : nil     # Set to board ID - will use the board's account and grant access (highest priority)
BOARD_IDS = nil    # Set to array of board IDs to grant access to multiple boards

# Main execution
puts "Creating API tokens and board access for Fizzy simulator agents..."
puts "=" * 80

# Get account - priority: BOARD_ID > ACCOUNT_ID > ACCOUNT_NAME > first account
account = if BOARD_ID
  board = Board.find(BOARD_ID)
  board.account.tap do |acc|
    puts "Using account from board: #{board.name} → #{acc.name}"
  end
elsif ACCOUNT_ID
  Account.find(ACCOUNT_ID)
elsif ACCOUNT_NAME
  Account.find_by!(name: ACCOUNT_NAME)
else
  Account.first || Account.create!(name: "Test Account", external_account_id: 1)
end

puts "\nAccount: #{account.name} (ID: #{account.id})"

# Determine which boards to grant access to
boards_to_access = []
if BOARD_ID
  boards_to_access << Board.find(BOARD_ID)
elsif BOARD_IDS
  boards_to_access = BOARD_IDS.map { |id| Board.find(id) }
end

if boards_to_access.any?
  puts "\nBoards to grant access to:"
  boards_to_access.each { |b| puts "  - #{b.name} (ID: #{b.id})" }
else
  puts "\n⚠️  No boards specified - agents will be created but won't have board access"
  puts "   Set BOARD_ID or BOARD_IDS to grant access"
end

puts "\n" + "=" * 80
puts "Processing agents:\n"

tokens_created = {}

AGENTS.each do |agent|
  puts "\n#{agent[:name]} (#{agent[:email]}):"
  puts "-" * 60
  
  # 1. Create or find Identity
  identity = find_or_create_identity(agent[:email])
  
  # 2. Create or find User
  user = find_or_create_user(account, identity, agent[:name], agent[:role])
  
  # 3. Create API token
  token = create_api_token(account, user, agent[:name])
  tokens_created[agent[:email]] = token.token
  
  # 4. Grant board access
  if boards_to_access.any?
    boards_to_access.each do |board|
      grant_board_access(user, board, account)
    end
  end
end

puts "\n" + "=" * 80
puts "Summary - Tokens created:"
puts "=" * 80
puts ""
puts "# Copy this to config/fizzy_sim/api_tokens.yml"
puts ""
puts "tokens:"
tokens_created.each do |email, token|
  puts "  #{email}: #{token}"
end
puts ""
puts "=" * 80
puts "Done! #{tokens_created.size} tokens created."
if boards_to_access.any?
  puts "All agents have been granted access to #{boards_to_access.size} board(s)."
else
  puts "⚠️  Remember to grant board access manually or set BOARD_ID/BOARD_IDS."
end
puts "=" * 80
