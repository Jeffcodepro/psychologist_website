require "test_helper"
require "timeout"

class PublicationConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  test "a visitor rendering during publication sees a complete snapshot and the next visit sees the update" do
    tenant = Tenant.create!(name: "Concorrência", slug: "publication-concurrency", domain: "publication.example")
    tenant.create_site_setting!(professional_name: "Concorrência")
    content = tenant.pages.create!(name: "Home", slug: "home")
    section = content.sections.create!(section_type: "cards", title: "Bloco anterior")
    card = section.section_items.create!(title: "Card anterior", body: "Conteúdo anterior")
    PagePublicationService.new(page: content).call
    section.update!(title: "Bloco novo")
    card.update!(title: "Card novo", body: "Conteúdo novo")
    entered = Queue.new
    resume = Queue.new
    reader = nil
    subscriber = Object.new
    subscriber.define_singleton_method(:start) do |_name, _id, payload|
      if Thread.current == reader && payload[:identifier].to_s.end_with?('/sections/_card_collection.html.erb')
        entered << true
        resume.pop
      end
    end
    subscriber.define_singleton_method(:finish) { |*| }
    subscription = ActiveSupport::Notifications.subscribe('render_partial.action_view', subscriber)
    reader = Thread.new do
      Rails.application.executor.wrap do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host!('publication.example')
        session.get('/')
        [session.response.status, session.response.body]
      end
    end
    Timeout.timeout(15) { entered.pop }
    PagePublicationService.new(page: content).call
    resume << true
    status, body = Timeout.timeout(15) { reader.value }
    assert_equal 200, status
    assert_includes body, 'Bloco anterior'
    assert_includes body, 'Card anterior'
    assert_not_includes body, 'Card novo'
    host!('publication.example')
    get '/'
    assert_response :success
    assert_includes response.body, 'Bloco novo'
    assert_includes response.body, 'Card novo'
    assert_not_includes response.body, 'Card anterior'
  ensure
    resume << true if resume
    reader&.join(2)
    reader&.kill if reader&.alive?
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
    if tenant
      tenant.pages.destroy_all
      tenant.site_setting&.destroy!
      tenant.reload.destroy!
    end
  end
end
