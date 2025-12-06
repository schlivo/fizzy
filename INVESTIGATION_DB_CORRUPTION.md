# Investigation: Database Corruption

## Problem Identified

SQLite database corruption appears to be caused by **double execution** of mention and card_link creation operations.

## Problematic Sequence

1. **Commit 4fa226c47**: "Create mentions and card_links synchronously in API"
   - Adds synchronous calls to `create_mentions` and `create_card_links` in `Api::CommentsController#create`

2. **Problem**: When a comment is created via the API:
   - The comment is created with `create!`
   - The `after_save_commit` callbacks are triggered:
     - `create_mentions_later` → launches `Mention::CreateJob` in the background
     - `create_card_links_later` → launches `CardLink::CreateJob` in the background
   - Then, we manually call `create_mentions` and `create_card_links` synchronously
   - The background jobs also execute and try to create the same mentions/card_links

3. **Result**: Double creation with concurrent transactions that can corrupt SQLite, especially with WAL mode.

## Files Involved

- `app/controllers/api/comments_controller.rb` (lines 18-21)
- `app/models/concerns/mentions.rb` (line 7: `after_save_commit :create_mentions_later`)
- `app/models/concerns/card_links.rb` (line 7: `after_save_commit :create_card_links_later`)

## Applied Solution

**Modified file**: `app/controllers/api/comments_controller.rb`

Disable `after_save_commit` callbacks **before** comment creation to prevent double execution:

```ruby
# Disable callbacks before creation to prevent double execution
Comment.skip_callback(:commit, :after, :create_mentions_later, raise: false)
Comment.skip_callback(:commit, :after, :create_card_links_later, raise: false)

begin
  comment = @card.comments.create!(...)
  comment.create_mentions(mentioner: Current.user)
  comment.create_card_links(creator: Current.user)
ensure
  # Re-enable callbacks for future operations
  Comment.set_callback(:commit, :after, :create_mentions_later)
  Comment.set_callback(:commit, :after, :create_card_links_later)
end
```

This avoids:
- Double creation of mentions/card_links
- Concurrent transactions that can corrupt SQLite
- Problems with SQLite WAL mode

## Other Related Changes

1. **SQLite journal mode fix**: `config/initializers/sqlite_journal_mode.rb` (REMOVED)
   - Was a workaround for I/O errors with WAL
   - **Removed** because the root cause (double execution) is fixed
   - Rails 7.1+ uses WAL by default, which should work correctly now

2. **Error handling improvement**: `app/controllers/api/base_controller.rb`
   - Added `rescue_from StandardError` to catch all exceptions
   - Always returns JSON instead of HTML/JavaScript
