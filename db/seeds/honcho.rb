create_tenant "honcho"

david = create_first_run "David Heinemeier Hansson", "david@37signals.com"
login_as david

jason = create_user "Jason Zimdars", "jz@37signals.com"
kevin = create_user "Kevin Mcconnell", "kevin@37signals.com"
sarah = create_user "Sarah Johnson", "sarah@37signals.com"
mike = create_user "Mike Peterson", "mike@37signals.com"

# Array of authors for random assignment
authors = [david, jason, kevin, sarah, mike]

# Card titles for reuse across collections
card_titles = [
  "Implement authentication",
  "Design landing page",
  "Set up database",
  "Create API endpoints",
  "Write unit tests",
  "Optimize performance",
  "Add user profiles",
  "Implement search",
  "Create admin panel",
  "Set up CI/CD",
  "Design logo",
  "Create documentation",
  "Add payment system",
  "Implement notifications",
  "Set up analytics",
  "Create mobile layout",
  "Add social sharing",
  "Implement caching",
  "Set up monitoring",
  "Create error handling"
]

# Create 10 collections
collections = [
  "Project Launch",
  "Frontend Dev",
  "Backend Dev",
  "Design System",
  "Testing Suite",
  "Performance",
  "User Experience",
  "API Development",
  "DevOps",
  "Documentation"
]

collections.each_with_index do |collection_name, index|
  create_collection(collection_name, access_to: authors.sample(3)).tap do |collection|
    # Create 20 unique cards for each collection
    card_titles.each do |title|
      create_card(title,
        description: "#{title} for #{collection_name} phase #{index + 1}.",
        collection: collection
      ).tap do |card|
        # Randomly assign to 1-2 authors
        card.toggle_assignment(authors.sample)
        card.toggle_assignment(authors.sample) if rand > 0.5
 
        # Randomly set card state
        case rand(3)
        when 0
          card.engage
        when 1
          card.close
        # 2 remains open
        end
      end
    end
  end
end
