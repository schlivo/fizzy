#!/usr/bin/env ruby

require_relative "../../config/environment"

# Script to clean up old records in the database
# Deletes very old events, comments, and notifications according to configurable thresholds

# Parse arguments
dry_run = ARGV.include?("--dry-run")
events_retention_days = 365
comments_retention_days = 180
notifications_retention_days = 90

ARGV.each_with_index do |arg, index|
  case arg
  when "--events-retention-days"
    events_retention_days = ARGV[index + 1].to_i if ARGV[index + 1]
  when "--comments-retention-days"
    comments_retention_days = ARGV[index + 1].to_i if ARGV[index + 1]
  when "--notifications-retention-days"
    notifications_retention_days = ARGV[index + 1].to_i if ARGV[index + 1]
  end
end

stats = {
  events: 0,
  comments: 0,
  notifications: 0
}

puts "=== Cleaning up old records ==="
puts "Mode: #{dry_run ? 'DRY-RUN (no deletion)' : 'DELETION'}"
puts "Retention thresholds:"
puts "  - Events: #{events_retention_days} days"
puts "  - Comments on closed cards: #{comments_retention_days} days after closure"
puts "  - Read notifications: #{notifications_retention_days} days"
puts

Account.find_each do |account|
  Current.account = account
  puts "Processing account: #{account.name} (ID: #{account.id})"
  puts

  # 1. Very old events
  events_threshold = events_retention_days.days.ago
  old_events = Event.where("created_at < ?", events_threshold)
  stats[:events] = old_events.count
  if stats[:events] > 0
    puts "  Old events (> #{events_retention_days} days): #{stats[:events]}"
    if dry_run
      old_events.limit(10).find_each { |e| puts "    - Event #{e.id} (#{e.eventable_type}##{e.eventable_id}, #{e.created_at.to_date})" }
      puts "    ... (display limited to 10)" if stats[:events] > 10
    else
      deleted_count = 0
      old_events.find_each do |event|
        event.destroy
        deleted_count += 1
        print "." if deleted_count % 100 == 0
      end
      puts
      puts "    ✓ #{deleted_count} deleted"
    end
  end

  # 2. Comments on cards closed long ago
  # We clean up comments on cards that were closed more than X days ago
  comments_threshold = comments_retention_days.days.ago
  old_comments = Comment.joins(:card)
                        .joins("INNER JOIN closures ON closures.card_id = cards.id")
                        .where("closures.created_at < ?", comments_threshold)
  stats[:comments] = old_comments.count
  if stats[:comments] > 0
    puts "  Comments on closed cards (> #{comments_retention_days} days): #{stats[:comments]}"
    if dry_run
      old_comments.limit(10).find_each { |c| puts "    - Comment #{c.id} (card_id: #{c.card_id}, #{c.created_at.to_date})" }
      puts "    ... (display limited to 10)" if stats[:comments] > 10
    else
      deleted_count = 0
      old_comments.find_each do |comment|
        comment.destroy
        deleted_count += 1
        print "." if deleted_count % 100 == 0
      end
      puts
      puts "    ✓ #{deleted_count} deleted"
    end
  end

  # 3. Events related to cards closed long ago
  # We clean up events related to cards that were closed more than X days ago
  old_card_events = Event.where(eventable_type: "Card")
                          .joins("INNER JOIN closures ON closures.card_id = events.eventable_id")
                          .where("closures.created_at < ?", comments_threshold)
  old_card_events_count = old_card_events.count
  if old_card_events_count > 0
    puts "  Events on closed cards (> #{comments_retention_days} days): #{old_card_events_count}"
    if dry_run
      old_card_events.limit(10).find_each { |e| puts "    - Event #{e.id} (card_id: #{e.eventable_id}, #{e.created_at.to_date})" }
      puts "    ... (display limited to 10)" if old_card_events_count > 10
    else
      deleted_count = 0
      old_card_events.find_each do |event|
        event.destroy
        deleted_count += 1
        print "." if deleted_count % 100 == 0
      end
      puts
      puts "    ✓ #{deleted_count} deleted"
    end
    stats[:events] += old_card_events_count
  end

  # 4. Old and already read notifications
  notifications_threshold = notifications_retention_days.days.ago
  old_notifications = Notification.read.where("read_at < ?", notifications_threshold)
  stats[:notifications] = old_notifications.count
  if stats[:notifications] > 0
    puts "  Old read notifications (> #{notifications_retention_days} days): #{stats[:notifications]}"
    if dry_run
      old_notifications.limit(10).find_each { |n| puts "    - Notification #{n.id} (user_id: #{n.user_id}, read on #{n.read_at.to_date})" }
      puts "    ... (display limited to 10)" if stats[:notifications] > 10
    else
      deleted_count = 0
      old_notifications.find_each do |notification|
        notification.destroy
        deleted_count += 1
        print "." if deleted_count % 100 == 0
      end
      puts
      puts "    ✓ #{deleted_count} deleted"
    end
  end

  puts
end

puts "=== Summary ==="
total = stats.values.sum
if total > 0
  stats.each do |type, count|
    puts "  #{type.to_s.capitalize}: #{count}" if count > 0
  end
  puts "  Total: #{total} record(s)"
  if dry_run
    puts
    puts "To perform deletion, run again without --dry-run"
  end
else
  puts "  No old records found according to configured thresholds."
end
puts "=== Completed ==="
