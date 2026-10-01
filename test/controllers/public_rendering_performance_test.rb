require "test_helper"
require "base64"

class PublicRenderingPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(name: "Performance", slug: "query-budget", primary: true)
    @tenant.create_site_setting!(professional_name: "Performance")
    @page = @tenant.pages.create!(name: "Home", slug: "home", published: true)
    @section = @page.sections.create!(section_type: "cards", title: "Cards", publication_state: "published")
    @article = @tenant.pages.create!(name: "Article", slug: "article", published: true, content_kind: "article")
    @article.sections.create!(section_type: "text", title: "Rascunho", body: "NEVER_RENDER_DRAFT")
    @article.sections.create!(section_type: "text", title: "Publicado", body: "Public summary", publication_state: "published")
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jhXkAAAAASUVORK5CYII=')
    @blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "card.png", content_type: "image/png")
    add_cards(1)
  end

  test "adding dozens of image cards does not add queries per card or leak unpublished content" do
    small = query_count { get root_path }
    add_cards(35)
    @section.section_items.create!(title: "HIDDEN_CARD", visible: false)
    large = query_count { get root_path }
    assert_response :success
    assert_select '.compact-card', count: 36
    assert_select '.compact-card__image', count: 36
    assert_includes response.body, 'Public summary'
    assert_not_includes response.body, 'NEVER_RENDER_DRAFT'
    assert_not_includes response.body, 'HIDDEN_CARD'
    assert_operator large, :<=, small + 2, "SQL queries grew with card count: #{small} -> #{large}"
    assert_operator large, :<=, 30, "Public response exceeded its SQL query budget: #{large}"
  end

  private

  def add_cards(count)
    count.times do |i|
      item = @section.section_items.create!(title: "Card #{i}", linked_page: @article)
      item.image.attach(@blob)
    end
  end

  def query_count
    queries = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries += 1 unless payload[:cached] || payload[:name] == 'SCHEMA' || payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
