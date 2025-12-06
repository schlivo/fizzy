#!/usr/bin/env ruby

require_relative "../../config/environment"

# Script to clean up orphaned records in the database
# Orphaned records are records that reference deleted entities

dry_run = ARGV.include?("--dry-run")

stats = {
  comments: 0,
  events: 0,
  taggings: 0,
  mentions: 0,
  notifications: 0,
  assignments: 0,
  watches: 0,
  pins: 0,
  reactions: 0
}

puts "=== Cleaning up orphaned records ==="
puts "Mode: #{dry_run ? 'DRY-RUN (no deletion)' : 'DELETION'}"
puts

Account.find_each do |account|
  Current.account = account
  puts "Processing account: #{account.name} (ID: #{account.id})"
  puts

  # 1. Comments without valid card
  orphaned_comments = Comment.where.not(card_id: Card.select(:id))
  stats[:comments] = orphaned_comments.count
  if stats[:comments] > 0
    puts "  Orphaned comments: #{stats[:comments]}"
    if dry_run
      orphaned_comments.find_each { |c| puts "    - Comment #{c.id} (card_id: #{c.card_id})" }
    else
      orphaned_comments.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 2. Events without valid eventable (polymorphic)
  # Check for each possible type (Card, Comment, Board, etc.)
  eventable_types = Event.distinct.pluck(:eventable_type).compact
  orphaned_event_ids = []
  
  eventable_types.each do |type|
    klass = type.constantize rescue nil
    next unless klass
    
    orphaned_for_type = Event.where(eventable_type: type)
                              .where.not(eventable_id: klass.select(:id))
    orphaned_event_ids.concat(orphaned_for_type.pluck(:id))
  end
  
  orphaned_events = Event.where(id: orphaned_event_ids.uniq)
  stats[:events] = orphaned_events.count
  if stats[:events] > 0
    puts "  Orphaned events: #{stats[:events]}"
    if dry_run
      orphaned_events.find_each { |e| puts "    - Event #{e.id} (#{e.eventable_type}##{e.eventable_id})" }
    else
      orphaned_events.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 3. Taggings without valid card or tag
  orphaned_taggings = Tagging.where.not(card_id: Card.select(:id))
                              .or(Tagging.where.not(tag_id: Tag.select(:id)))
  stats[:taggings] = orphaned_taggings.count
  if stats[:taggings] > 0
    puts "  Orphaned taggings: #{stats[:taggings]}"
    if dry_run
      orphaned_taggings.find_each { |t| puts "    - Tagging #{t.id} (card_id: #{t.card_id}, tag_id: #{t.tag_id})" }
    else
      orphaned_taggings.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 4. Mentions without valid source (polymorphic)
  mention_source_types = Mention.distinct.pluck(:source_type).compact
  orphaned_mention_ids = []
  
  mention_source_types.each do |type|
    klass = type.constantize rescue nil
    next unless klass
    
    orphaned_for_type = Mention.where(source_type: type)
                                .where.not(source_id: klass.select(:id))
    orphaned_mention_ids.concat(orphaned_for_type.pluck(:id))
  end
  
  # Also check mentions without valid mentioner or mentionee
  orphaned_mention_ids.concat(
    Mention.where.not(mentioner_id: User.select(:id)).pluck(:id)
  )
  orphaned_mention_ids.concat(
    Mention.where.not(mentionee_id: User.select(:id)).pluck(:id)
  )
  
  orphaned_mentions = Mention.where(id: orphaned_mention_ids.uniq)
  stats[:mentions] = orphaned_mentions.count
  if stats[:mentions] > 0
    puts "  Orphaned mentions: #{stats[:mentions]}"
    if dry_run
      orphaned_mentions.find_each { |m| puts "    - Mention #{m.id} (#{m.source_type}##{m.source_id})" }
    else
      orphaned_mentions.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 5. Notifications without valid source (polymorphic)
  notification_source_types = Notification.distinct.pluck(:source_type).compact
  orphaned_notification_ids = []
  
  notification_source_types.each do |type|
    klass = type.constantize rescue nil
    next unless klass
    
    orphaned_for_type = Notification.where(source_type: type)
                                    .where.not(source_id: klass.select(:id))
    orphaned_notification_ids.concat(orphaned_for_type.pluck(:id))
  end
  
  # Also check notifications without valid user or creator
  orphaned_notification_ids.concat(
    Notification.where.not(user_id: User.select(:id)).pluck(:id)
  )
  orphaned_notification_ids.concat(
    Notification.where.not(creator_id: User.select(:id)).pluck(:id)
  )
  
  orphaned_notifications = Notification.where(id: orphaned_notification_ids.uniq)
  stats[:notifications] = orphaned_notifications.count
  if stats[:notifications] > 0
    puts "  Orphaned notifications: #{stats[:notifications]}"
    if dry_run
      orphaned_notifications.find_each { |n| puts "    - Notification #{n.id} (#{n.source_type}##{n.source_id})" }
    else
      orphaned_notifications.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 6. Assignments without valid card or assignee/assigner
  orphaned_assignments = Assignment.where.not(card_id: Card.select(:id))
                                   .or(Assignment.where.not(assignee_id: User.select(:id)))
                                   .or(Assignment.where.not(assigner_id: User.select(:id)))
  stats[:assignments] = orphaned_assignments.count
  if stats[:assignments] > 0
    puts "  Orphaned assignments: #{stats[:assignments]}"
    if dry_run
      orphaned_assignments.find_each { |a| puts "    - Assignment #{a.id} (card_id: #{a.card_id})" }
    else
      orphaned_assignments.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 7. Watches without valid card or user
  orphaned_watches = Watch.where.not(card_id: Card.select(:id))
                           .or(Watch.where.not(user_id: User.select(:id)))
  stats[:watches] = orphaned_watches.count
  if stats[:watches] > 0
    puts "  Orphaned watches: #{stats[:watches]}"
    if dry_run
      orphaned_watches.find_each { |w| puts "    - Watch #{w.id} (card_id: #{w.card_id}, user_id: #{w.user_id})" }
    else
      orphaned_watches.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 8. Pins without valid card or user
  orphaned_pins = Pin.where.not(card_id: Card.select(:id))
                      .or(Pin.where.not(user_id: User.select(:id)))
  stats[:pins] = orphaned_pins.count
  if stats[:pins] > 0
    puts "  Orphaned pins: #{stats[:pins]}"
    if dry_run
      orphaned_pins.find_each { |p| puts "    - Pin #{p.id} (card_id: #{p.card_id}, user_id: #{p.user_id})" }
    else
      orphaned_pins.find_each(&:destroy)
      puts "    ✓ Deleted"
    end
  end

  # 9. Reactions without valid comment
  orphaned_reactions = Reaction.where.not(comment_id: Comment.select(:id))
                                .or(Reaction.where.not(reacter_id: User.select(:id)))
  stats[:reactions] = orphaned_reactions.count
  if stats[:reactions] > 0
    puts "  Orphaned reactions: #{stats[:reactions]}"
    if dry_run
      orphaned_reactions.find_each { |r| puts "    - Reaction #{r.id} (comment_id: #{r.comment_id})" }
    else
      orphaned_reactions.find_each(&:destroy)
      puts "    ✓ Deleted"
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
  puts "  No orphaned records found."
end
puts "=== Completed ==="
