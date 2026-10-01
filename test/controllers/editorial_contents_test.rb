require 'test_helper'
require 'base64'

class EditorialContentsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: 'Editorial', slug: 'editorial', primary: true)
    @tenant.create_site_setting!(professional_name: 'Editorial')
    @user = @tenant.users.create!(admin: true, email: 'editor@example.test', password: 'Editor-password-123!')
    @page = @tenant.pages.create!(name: 'Conteúdos', slug: 'conteudos', show_in_nav: true)
    @section = @page.sections.create!(section_type: 'cards', title: 'Destaques')
    @card = @section.section_items.create!(title: 'Um novo caminho', title_en: 'A new path', body: 'Resumo do texto.', body_en: 'Article summary.')
    sign_in @user
  end

  test 'blog creates and edits articles and reflections using the page block editor' do
    get admin_articles_path
    assert_response :success
    get new_admin_article_path
    assert_select 'form[action=?]', admin_articles_path(locale: 'pt-BR')
    assert_difference '@tenant.pages.editorial.count', 1 do
      post admin_articles_path, params: { page: { name: 'Reflexão de hoje', content_kind: 'reflection' } }
    end
    article = @tenant.pages.editorial.last
    assert_redirected_to admin_page_sections_path(article, locale: 'pt-BR')
    assert_not article.published?
    assert_not article.show_in_nav?
    assert_equal %w[hero text], article.sections.draft.ordered.pluck(:section_type)
    block = article.sections.draft.find_by!(section_type: 'text')
    patch admin_page_section_path(article, block), params: { section: { body: "Primeiro parágrafo.\n\nSegundo parágrafo.", body_en: 'English text.', body_font_family: 'lora' } }
    assert_response :redirect
    assert_equal 'English text.', block.reload.body_en
    get admin_pages_path
    assert_select "a[href*='/admin/pages/#{article.id}/']", count: 0
    get admin_articles_path
    assert_includes response.body, 'Reflexão de hoje'
    patch admin_page_path(article), params: { page: { content_kind: 'article', name: 'Artigo revisado' } }
    assert_redirected_to admin_articles_path(locale: 'pt-BR')
    assert_equal 'article', article.reload.content_kind
  end

  test 'create full text from a card retains bilingual content and links only its draft' do
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jhXkAAAAASUVORK5CYII=')
    @card.image.attach(io: StringIO.new(png), filename: 'card.png', content_type: 'image/png')
    @card.update!(image_position_x: 35, image_zoom: 1.5)
    PagePublicationService.new(page: @page).call
    assert_difference '@tenant.pages.editorial.count', 1 do
      patch admin_page_section_section_item_path(@page, @section, @card), params: { from_preview: '1', write_article: '1', section_item: { title: @card.title } }
    end
    article = @card.reload.linked_page
    assert_redirected_to admin_page_sections_path(article, locale: 'pt-BR')
    assert_equal 'A new path', article.sections.draft.find_by!(section_type: 'hero').title_en
    assert_equal @card.body, article.sections.draft.find_by!(section_type: 'text').body
    heading = article.sections.draft.find_by!(section_type: 'hero')
    assert_equal @card.image.blob_id, heading.image.blob_id
    assert_equal 35, heading.image_position_x
    assert_equal 1.5, heading.image_zoom
    assert_nil @page.sections.published.first.section_items.first.linked_page_id
    assert_no_difference 'Page.count' do
      patch admin_page_section_section_item_path(@page, @section, @card), params: { write_article: '1', section_item: { title: @card.title } }
    end
    get admin_page_preview_frame_path(@page, locale: 'en')
    assert_select ".compact-card__link[href='#{admin_page_preview_path(article, locale: 'en')}'][target='_top']", text: /Learn more/
    assert_select '.compact-card--linked[data-controller="card-reader"]', count: 0
    get admin_page_sections_path(article)
    assert_select "a[href*='/section_items/#{@card.id}/edit']", text: /Voltar ao card/
  end

  test 'public cards link to published content respecting tenant and language and preserve publication snapshots' do
    article = ArticleFromCardService.call(card: @card)
    PagePublicationService.new(page: @page).call
    sign_out @user
    get public_page_path(slug: @page.slug, site_slug: @tenant.slug)
    assert_response :success
    assert_select '.compact-card__link', count: 0
    get public_page_path(slug: article.slug, site_slug: @tenant.slug)
    assert_response :not_found
    PagePublicationService.new(page: article).call
    get public_page_path(slug: @page.slug, site_slug: @tenant.slug, locale: 'en')
    assert_response :see_other
    follow_redirect!
    assert_select '.compact-card__link', count: 1
    assert_select "a[href='#{public_page_path(slug: article.slug, site_slug: @tenant.slug)}']"
    get public_page_path(slug: article.slug, site_slug: @tenant.slug)
    assert_includes response.body, 'Article summary.'
    article.sections.draft.find_by!(section_type: 'text').update!(body_en: 'New unpublished text')
    get public_page_path(slug: article.slug, site_slug: @tenant.slug)
    assert_not_includes response.body, 'New unpublished text'
    assert_select 'a[href*="/admin/"]', count: 0
  end

  test 'cards can change or remove destinations and deleting a text keeps the cards' do
    article = ArticleFromCardService.call(card: @card)
    other_page = @tenant.pages.create!(name: 'Outra página')
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { linked_page_id: other_page.id } }
    assert_equal other_page.id, @card.reload.linked_page_id
    patch admin_page_section_section_item_path(@page, @section, @card), params: { section_item: { linked_page_id: '' } }
    assert_nil @card.reload.linked_page_id
    @card.update!(linked_page: article)
    PagePublicationService.new(page: @page).call
    assert_no_difference 'SectionItem.count' do
      delete admin_page_path(article)
    end
    assert_redirected_to admin_articles_path(locale: 'pt-BR')
    assert_nil @card.reload.linked_page_id
    assert_nil @page.sections.published.first.section_items.first.linked_page_id
  end

  test 'foreign destinations and foreign article editing are rejected and failed saves create no orphan texts' do
    other = Tenant.create!(name: 'Other', slug: 'other-editor')
    foreign = other.pages.create!(name: 'Private article', content_kind: 'article')
    assert_no_difference 'Page.count' do
      patch admin_page_section_section_item_path(@page, @section, @card), params: { write_article: '1', section_item: { linked_page_id: foreign.id } }
      assert_response :unprocessable_entity
    end
    assert_nil @card.reload.linked_page_id
    assert_no_difference 'Page.count' do
      post admin_page_section_section_items_path(@page, @section), params: { write_article: '1', section_item: { title: '', item_kind: 'card' } }
      assert_response :unprocessable_entity
    end
    get edit_admin_page_path(foreign)
    assert_response :not_found
    get admin_page_preview_frame_path(foreign)
    assert_response :not_found
    get admin_articles_path
    assert_not_includes response.body, foreign.name
    get edit_admin_page_section_section_item_path(@page, @section, @card)
    assert_select "option[value='#{foreign.id}']", count: 0
  end

  test 'new texts validate their kind and cannot be published or assigned to a foreign tenant through form parameters' do
    assert_no_difference 'Page.count' do
      post admin_articles_path, params: { page: { name: 'Invalid kind', content_kind: 'page' } }
      assert_response :unprocessable_entity
    end
    other = Tenant.create!(name: 'Another client', slug: 'another-editor')
    post admin_articles_path, params: { page: { name: 'Valid article', content_kind: 'article', tenant_id: other.id, published: true } }
    assert_response :redirect
    article = @tenant.pages.editorial.last
    assert_equal @tenant.id, article.tenant_id
    assert_not article.published?
    assert_empty other.pages
  end

  test 'publication date is set on first release and survives later publications with localized display' do
    article = ArticleFromCardService.call(card: @card)
    get admin_page_preview_frame_path(article)
    assert_select '.article-publication', count: 0

    first_release = Time.zone.local(2026, 9, 27, 23, 30)
    travel_to first_release do
      PagePublicationService.new(page: article).call
      assert_equal first_release, article.reload.published_at
    end
    travel_to first_release + 2.days do
      article.sections.draft.find_by!(section_type: 'text').update!(body: 'Texto revisado.')
      PagePublicationService.new(page: article).call
      assert_equal first_release, article.reload.published_at
    end

    get admin_page_preview_path(article)
    assert_select '.admin-preview-header .article-publication time', text: '27/09/2026'
    get admin_page_preview_frame_path(article, locale: 'en')
    assert_select '.article-publication', text: /Published on.*September 27, 2026/m

    PagePublicationService.new(page: @page).call
    sign_out @user
    get public_page_path(slug: article.slug, site_slug: @tenant.slug, locale: nil)
    assert_response :success
    assert_select '.article-publication time[datetime=?]', first_release.iso8601, text: '27/09/2026'
    get public_page_path(slug: @page.slug, site_slug: @tenant.slug)
    assert_select '.article-publication-header', count: 0
    assert_select '.compact-card .article-publication time', text: '27/09/2026'
  end
end
