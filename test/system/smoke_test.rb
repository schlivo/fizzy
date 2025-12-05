require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "create a card" do
    sign_in_as(users(:david))

    visit board_url(boards(:writebook))
    click_on "Add a card"
    fill_in "card_title", with: "Hello, world!"
    fill_in_lexxy with: "I am editing this thing"
    click_on "Create card"

    assert_selector "h3", text: "Hello, world!"
  end

  test "active storage attachments" do
    sign_in_as(users(:david))

    visit card_url(cards(:layout))
    fill_in_lexxy with: "Here is a comment"
    attach_file file_fixture("moon.jpg") do
      click_on "Upload file"
    end

    within("form lexxy-editor figure.attachment[data-content-type='image/jpeg']") do
      assert_selector "img[src*='/rails/active_storage']"
      assert_selector "figcaption input[placeholder='moon.jpg']"
    end

    click_on "Post"

    within("action-text-attachment") do
      assert_selector "a img[src*='/rails/active_storage']"
      assert_selector "figcaption span.attachment__name", text: "moon.jpg"
    end
  end

  test "dismissing notifications" do
    sign_in_as(users(:david))

    notif = notifications(:logo_card_david_mention_by_jz)

    assert_selector "div##{dom_id(notif)}"

    new_window = open_new_window
    switch_to_window(new_window)
    visit card_url(notif.card)
    # Wait for the page to load completely, including JavaScript
    assert_selector "h1", wait: 5
    # Force the beacon to fire by triggering visibility change
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
    # Give the beacon controller time to fire
    sleep 0.5

    # Wait for the notification to be marked as read in the database
    # The beacon fires asynchronously, so we need to wait a bit
    10.times do
      break if notif.reload.read?
      sleep 0.2
    end
    assert_predicate notif, :read?, "Notification should be marked as read after visiting the card"

    # Switch back to the original window to check the DOM
    switch_to_window(windows.first)

    # Wait for the Turbo Stream broadcast to remove the notification from the DOM
    assert_no_selector "div##{dom_id(notif)}", wait: 5
  end

  test "dragging card to a new column" do
    sign_in_as(users(:david))

    card = Card.find("03axhd1h3qgnsffqplkyf28fv")
    assert_nil(card.column)

    visit board_url(boards(:writebook))

    card_el = page.find("#article_card_03axhd1h3qgnsffqplkyf28fv")
    column_el = page.find("#column_03axmcferfmbnv4qg816nw6bg")
    cards_count = column_el.find(".cards__expander-count").text.to_i

    card_el.drag_to(column_el)

    column_el.find(".cards__expander-count", text: cards_count + 1)
    assert_equal("Triage", card.reload.column.name)
  end

  private
    def sign_in_as(user)
      visit session_transfer_url(user.identity.transfer_id, script_name: nil)
      assert_selector "h1", text: "Latest Activity"
    end

    def fill_in_lexxy(selector = "lexxy-editor", with:)
      editor_element = find(selector)
      editor_element.set with
      page.execute_script("arguments[0].value = '#{with}'", editor_element)
    end
end
