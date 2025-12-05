#!/usr/bin/env ruby

require_relative "../../config/environment"

# Script principal de nettoyage de la base de données
# Combine le nettoyage des données orphelines et des anciennes données
# avec des options en ligne de commande

# Parse des arguments
orphaned_only = ARGV.include?("--orphaned-only")
old_only = ARGV.include?("--old-only")
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

# Déterminer ce qui doit être exécuté
run_orphaned = !old_only
run_old = !orphaned_only

if orphaned_only && old_only
  puts "Erreur: --orphaned-only et --old-only ne peuvent pas être utilisés ensemble"
  exit 1
end

puts "=== Script de nettoyage de la base de données ==="
puts "Mode: #{dry_run ? 'DRY-RUN (aucune suppression)' : 'SUPPRESSION'}"
puts
puts "Opérations à effectuer:"
puts "  - Nettoyage des données orphelines: #{run_orphaned ? 'OUI' : 'NON'}"
puts "  - Nettoyage des anciennes données: #{run_old ? 'OUI' : 'NON'}"
if run_old
  puts "  Seuils de rétention:"
  puts "    - Events: #{events_retention_days} jours"
  puts "    - Comments sur cards fermées: #{comments_retention_days} jours après fermeture"
  puts "    - Notifications lues: #{notifications_retention_days} jours"
end
puts
puts "=" * 60
puts

# Exécuter le nettoyage des données orphelines
if run_orphaned
  puts
  puts ">>> NETTOYAGE DES DONNÉES ORPHELINES <<<"
  puts
  
  # Simuler l'appel du script cleanup_orphaned_records.rb
  # On réutilise la logique mais on l'intègre ici
  stats_orphaned = {
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

  Account.find_each do |account|
    Current.account = account
    puts "Traitement du compte: #{account.name} (ID: #{account.id})"
    puts

    # 1. Comments sans card valide
    orphaned_comments = Comment.where.not(card_id: Card.select(:id))
    stats_orphaned[:comments] = orphaned_comments.count
    if stats_orphaned[:comments] > 0
      puts "  Comments orphelins: #{stats_orphaned[:comments]}"
      if dry_run
        orphaned_comments.limit(5).find_each { |c| puts "    - Comment #{c.id} (card_id: #{c.card_id})" }
        puts "    ... (affichage limité)" if stats_orphaned[:comments] > 5
      else
        orphaned_comments.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 2. Events sans eventable valide
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
    stats_orphaned[:events] = orphaned_events.count
    if stats_orphaned[:events] > 0
      puts "  Events orphelins: #{stats_orphaned[:events]}"
      if dry_run
        orphaned_events.limit(5).find_each { |e| puts "    - Event #{e.id} (#{e.eventable_type}##{e.eventable_id})" }
        puts "    ... (affichage limité)" if stats_orphaned[:events] > 5
      else
        orphaned_events.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 3. Taggings sans card ou sans tag valide
    orphaned_taggings = Tagging.where.not(card_id: Card.select(:id))
                                .or(Tagging.where.not(tag_id: Tag.select(:id)))
    stats_orphaned[:taggings] = orphaned_taggings.count
    if stats_orphaned[:taggings] > 0
      puts "  Taggings orphelins: #{stats_orphaned[:taggings]}"
      if dry_run
        orphaned_taggings.limit(5).find_each { |t| puts "    - Tagging #{t.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:taggings] > 5
      else
        orphaned_taggings.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 4. Mentions sans source valide
    mention_source_types = Mention.distinct.pluck(:source_type).compact
    orphaned_mention_ids = []
    
    mention_source_types.each do |type|
      klass = type.constantize rescue nil
      next unless klass
      
      orphaned_for_type = Mention.where(source_type: type)
                                  .where.not(source_id: klass.select(:id))
      orphaned_mention_ids.concat(orphaned_for_type.pluck(:id))
    end
    
    orphaned_mention_ids.concat(
      Mention.where.not(mentioner_id: User.select(:id)).pluck(:id)
    )
    orphaned_mention_ids.concat(
      Mention.where.not(mentionee_id: User.select(:id)).pluck(:id)
    )
    
    orphaned_mentions = Mention.where(id: orphaned_mention_ids.uniq)
    stats_orphaned[:mentions] = orphaned_mentions.count
    if stats_orphaned[:mentions] > 0
      puts "  Mentions orphelines: #{stats_orphaned[:mentions]}"
      if dry_run
        orphaned_mentions.limit(5).find_each { |m| puts "    - Mention #{m.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:mentions] > 5
      else
        orphaned_mentions.find_each(&:destroy)
        puts "    ✓ Supprimées"
      end
    end

    # 5. Notifications sans source valide
    notification_source_types = Notification.distinct.pluck(:source_type).compact
    orphaned_notification_ids = []
    
    notification_source_types.each do |type|
      klass = type.constantize rescue nil
      next unless klass
      
      orphaned_for_type = Notification.where(source_type: type)
                                      .where.not(source_id: klass.select(:id))
      orphaned_notification_ids.concat(orphaned_for_type.pluck(:id))
    end
    
    orphaned_notification_ids.concat(
      Notification.where.not(user_id: User.select(:id)).pluck(:id)
    )
    orphaned_notification_ids.concat(
      Notification.where.not(creator_id: User.select(:id)).pluck(:id)
    )
    
    orphaned_notifications = Notification.where(id: orphaned_notification_ids.uniq)
    stats_orphaned[:notifications] = orphaned_notifications.count
    if stats_orphaned[:notifications] > 0
      puts "  Notifications orphelines: #{stats_orphaned[:notifications]}"
      if dry_run
        orphaned_notifications.limit(5).find_each { |n| puts "    - Notification #{n.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:notifications] > 5
      else
        orphaned_notifications.find_each(&:destroy)
        puts "    ✓ Supprimées"
      end
    end

    # 6. Assignments sans card ou sans assignee/assigner valide
    orphaned_assignments = Assignment.where.not(card_id: Card.select(:id))
                                     .or(Assignment.where.not(assignee_id: User.select(:id)))
                                     .or(Assignment.where.not(assigner_id: User.select(:id)))
    stats_orphaned[:assignments] = orphaned_assignments.count
    if stats_orphaned[:assignments] > 0
      puts "  Assignments orphelins: #{stats_orphaned[:assignments]}"
      if dry_run
        orphaned_assignments.limit(5).find_each { |a| puts "    - Assignment #{a.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:assignments] > 5
      else
        orphaned_assignments.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 7. Watches sans card ou sans user valide
    orphaned_watches = Watch.where.not(card_id: Card.select(:id))
                             .or(Watch.where.not(user_id: User.select(:id)))
    stats_orphaned[:watches] = orphaned_watches.count
    if stats_orphaned[:watches] > 0
      puts "  Watches orphelins: #{stats_orphaned[:watches]}"
      if dry_run
        orphaned_watches.limit(5).find_each { |w| puts "    - Watch #{w.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:watches] > 5
      else
        orphaned_watches.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 8. Pins sans card ou sans user valide
    orphaned_pins = Pin.where.not(card_id: Card.select(:id))
                        .or(Pin.where.not(user_id: User.select(:id)))
    stats_orphaned[:pins] = orphaned_pins.count
    if stats_orphaned[:pins] > 0
      puts "  Pins orphelins: #{stats_orphaned[:pins]}"
      if dry_run
        orphaned_pins.limit(5).find_each { |p| puts "    - Pin #{p.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:pins] > 5
      else
        orphaned_pins.find_each(&:destroy)
        puts "    ✓ Supprimés"
      end
    end

    # 9. Reactions sans comment valide
    orphaned_reactions = Reaction.where.not(comment_id: Comment.select(:id))
                                  .or(Reaction.where.not(reacter_id: User.select(:id)))
    stats_orphaned[:reactions] = orphaned_reactions.count
    if stats_orphaned[:reactions] > 0
      puts "  Reactions orphelines: #{stats_orphaned[:reactions]}"
      if dry_run
        orphaned_reactions.limit(5).find_each { |r| puts "    - Reaction #{r.id}" }
        puts "    ... (affichage limité)" if stats_orphaned[:reactions] > 5
      else
        orphaned_reactions.find_each(&:destroy)
        puts "    ✓ Supprimées"
      end
    end

    puts
  end

  puts "=== Résumé - Données orphelines ==="
  total_orphaned = stats_orphaned.values.sum
  if total_orphaned > 0
    stats_orphaned.each do |type, count|
      puts "  #{type.to_s.capitalize}: #{count}" if count > 0
    end
    puts "  Total: #{total_orphaned} enregistrement(s)"
  else
    puts "  Aucune donnée orpheline trouvée."
  end
  puts
end

# Exécuter le nettoyage des anciennes données
if run_old
  puts
  puts ">>> NETTOYAGE DES ANCIENNES DONNÉES <<<"
  puts
  
  stats_old = {
    events: 0,
    comments: 0,
    notifications: 0
  }

  Account.find_each do |account|
    Current.account = account
    puts "Traitement du compte: #{account.name} (ID: #{account.id})"
    puts

    # 1. Events très anciens
    events_threshold = events_retention_days.days.ago
    old_events = Event.where("created_at < ?", events_threshold)
    stats_old[:events] = old_events.count
    if stats_old[:events] > 0
      puts "  Events anciens (> #{events_retention_days} jours): #{stats_old[:events]}"
      if dry_run
        old_events.limit(5).find_each { |e| puts "    - Event #{e.id} (#{e.created_at.to_date})" }
        puts "    ... (affichage limité)" if stats_old[:events] > 5
      else
        deleted_count = 0
        old_events.find_each do |event|
          event.destroy
          deleted_count += 1
          print "." if deleted_count % 100 == 0
        end
        puts
        puts "    ✓ #{deleted_count} supprimés"
      end
    end

    # 2. Comments sur des cards fermées depuis longtemps
    comments_threshold = comments_retention_days.days.ago
    old_comments = Comment.joins(:card)
                          .joins("INNER JOIN closures ON closures.card_id = cards.id")
                          .where("closures.created_at < ?", comments_threshold)
    stats_old[:comments] = old_comments.count
    if stats_old[:comments] > 0
      puts "  Comments sur cards fermées (> #{comments_retention_days} jours): #{stats_old[:comments]}"
      if dry_run
        old_comments.limit(5).find_each { |c| puts "    - Comment #{c.id} (card_id: #{c.card_id})" }
        puts "    ... (affichage limité)" if stats_old[:comments] > 5
      else
        deleted_count = 0
        old_comments.find_each do |comment|
          comment.destroy
          deleted_count += 1
          print "." if deleted_count % 100 == 0
        end
        puts
        puts "    ✓ #{deleted_count} supprimés"
      end
    end

    # 3. Events liés à des cards fermées depuis longtemps
    old_card_events = Event.where(eventable_type: "Card")
                            .joins("INNER JOIN closures ON closures.card_id = events.eventable_id")
                            .where("closures.created_at < ?", comments_threshold)
    old_card_events_count = old_card_events.count
    if old_card_events_count > 0
      puts "  Events sur cards fermées (> #{comments_retention_days} jours): #{old_card_events_count}"
      if dry_run
        old_card_events.limit(5).find_each { |e| puts "    - Event #{e.id} (card_id: #{e.eventable_id})" }
        puts "    ... (affichage limité)" if old_card_events_count > 5
      else
        deleted_count = 0
        old_card_events.find_each do |event|
          event.destroy
          deleted_count += 1
          print "." if deleted_count % 100 == 0
        end
        puts
        puts "    ✓ #{deleted_count} supprimés"
      end
      stats_old[:events] += old_card_events_count
    end

    # 4. Notifications anciennes et déjà lues
    notifications_threshold = notifications_retention_days.days.ago
    old_notifications = Notification.read.where("read_at < ?", notifications_threshold)
    stats_old[:notifications] = old_notifications.count
    if stats_old[:notifications] > 0
      puts "  Notifications lues anciennes (> #{notifications_retention_days} jours): #{stats_old[:notifications]}"
      if dry_run
        old_notifications.limit(5).find_each { |n| puts "    - Notification #{n.id} (user_id: #{n.user_id})" }
        puts "    ... (affichage limité)" if stats_old[:notifications] > 5
      else
        deleted_count = 0
        old_notifications.find_each do |notification|
          notification.destroy
          deleted_count += 1
          print "." if deleted_count % 100 == 0
        end
        puts
        puts "    ✓ #{deleted_count} supprimées"
      end
    end

    puts
  end

  puts "=== Résumé - Anciennes données ==="
  total_old = stats_old.values.sum
  if total_old > 0
    stats_old.each do |type, count|
      puts "  #{type.to_s.capitalize}: #{count}" if count > 0
    end
    puts "  Total: #{total_old} enregistrement(s)"
  else
    puts "  Aucune ancienne donnée trouvée selon les seuils configurés."
  end
  puts
end

puts "=" * 60
puts "=== RÉSUMÉ GLOBAL ==="
if dry_run
  puts "Mode DRY-RUN: aucune suppression effectuée"
  puts "Pour effectuer la suppression, relancez sans --dry-run"
else
  puts "Nettoyage terminé"
end
puts "=" * 60

