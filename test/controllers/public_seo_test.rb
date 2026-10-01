require "test_helper"

class PublicSeoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Rosemary", slug: "seo", domain: "rosemary.example", primary: true)
    @tenant.create_site_setting!(professional_name: "Rosemary Dias", seo_description: "Psicologia e escuta.")
    @page = @tenant.pages.create!(name: "Home", slug: "home", seo_title: "Rosemary | Psicologia", seo_title_en: "Rosemary | Psychology")
    @section = @page.sections.create!(section_type: "text", title: "Publicado", body: "Texto anterior")
    PagePublicationService.new(page: @page).call
    @draft = @tenant.pages.create!(name: "Rascunho secreto", slug: "rascunho")
    @article = @tenant.pages.create!(name: "Uma reflexão", slug: "uma-reflexao", content_kind: "article")
    PagePublicationService.new(page: @article).call
    host! "rosemary.example"
  end

  test "www redirects permanently to the known site preserving page and locale" do
    host! "www.rosemary.example"
    get '/uma-reflexao?locale=en'
    assert_response :moved_permanently
    assert_redirected_to 'http://rosemary.example/uma-reflexao?locale=en'
    follow_redirect!
    assert_response :see_other
    assert_redirected_to 'http://rosemary.example/uma-reflexao'
    follow_redirect!
    assert_response :success
    assert_select "link[rel='canonical'][href='http://rosemary.example/uma-reflexao']"
    host! "www.unknown.example"
    get '/'
    assert_response :not_found
  end

  test "explicit tenant domains take precedence over www aliases" do
    other = Tenant.create!(name: "Outro", slug: "other-www", domain: "www.rosemary.example")
    page = other.pages.create!(name: "Outro site", slug: "home", published: true)
    get root_path
    assert_select 'title', text: 'Rosemary | Psicologia'
    host! other.domain
    get root_path
    assert_response :success
    assert_select 'title', text: page.name
  end

  test "canonical and structured metadata use one public address for both languages" do
    get '/?utm_source=test&locale=en'
    assert_redirected_to '/?utm_source=test'
    follow_redirect!
    assert_response :success
    assert_select 'title', text: 'Rosemary | Psychology'
    assert_select "link[rel='canonical'][href='http://rosemary.example/']"
    assert_select "link[hreflang]", count: 0
    assert_select "meta[property='og:url'][content='http://rosemary.example/']"
    assert_select "meta[name='robots'][content*='index, follow']"
    assert_select 'a[href*="/admin"]', count: 0
    get '/uma-reflexao'
    data = JSON.parse(Nokogiri::HTML(response.body).at_css('script[type="application/ld+json"]').text)
    article = data['@graph'].find { |entry| entry['@type'] == 'BlogPosting' }
    assert_equal 'http://rosemary.example/uma-reflexao', article['url']
    assert article['datePublished'].present?
    assert_equal 'Rosemary Dias', article.dig('author', 'name')
  end

  test "sitemap and robots expose only published pages of the selected active tenant" do
    other = Tenant.create!(name: 'Outro', slug: 'other-seo', domain: 'other.example')
    other.pages.create!(name: 'Segredo de outro', slug: 'other-secret', published: true)
    get '/sitemap.xml'
    assert_response :success
    xml = Nokogiri::XML(response.body)
    assert_empty xml.errors
    urls = xml.xpath('//*[local-name()="loc"]').map(&:text)
    assert_equal 2, urls.size
    assert_includes urls, 'http://rosemary.example/'
    assert_includes urls, 'http://rosemary.example/uma-reflexao'
    assert_not_includes response.body, 'locale='
    assert_not_includes response.body, 'rascunho'
    assert_not_includes response.body, 'other-secret'
    get '/robots.txt'
    assert_response :success
    assert_includes response.body, 'Sitemap: http://rosemary.example/sitemap.xml'
    assert_includes response.body, 'Disallow: /admin'
    assert_not_includes response.body, 'Disallow: /\n'
    @tenant.update!(active: false)
    get '/sitemap.xml'
    assert_response :not_found
  end

  test "article republication preserves its publication date and updates sitemap lastmod" do
    original_date = @article.published_at
    travel 2.days do
      PagePublicationService.new(page: @article).call
      assert_equal original_date, @article.reload.published_at
      assert_in_delta Time.current.to_i, @article.updated_at.to_i, 1
      get '/sitemap.xml'
      xml = Nokogiri::XML(response.body)
      node = xml.xpath('//*[local-name()="url"]').find { |url| url.at_xpath('./*[local-name()="loc"]').text.end_with?('/uma-reflexao') }
      assert_equal @article.updated_at.iso8601, node.at_xpath('./*[local-name()="lastmod"]').text
    end
  end

  test "publication failures preserve public pages and an admin redirect cannot be cached" do
    @section.update!(body: 'Novo rascunho')
    ids = @page.sections.published.ids
    service = PagePublicationService.new(page: @page)
    service.define_singleton_method(:publish_sections) { raise 'Simulated failure' }
    assert_raises(RuntimeError) { service.call }
    assert_equal ids, @page.sections.published.ids
    get root_path
    assert_response :success
    assert_includes response.body, 'Texto anterior'
    assert_not_includes response.body, 'Novo rascunho'
    PagePublicationService.new(page: @page).call
    get root_path
    assert_response :success
    assert_includes response.body, 'Novo rascunho'
    user = @tenant.users.create!(admin: true, email: 'seo@example.test', password: 'Seo-test-password-123!')
    sign_in user
    get root_path
    assert_redirected_to admin_root_path
    assert_includes response.headers['Cache-Control'], 'no-store'
  end
end
