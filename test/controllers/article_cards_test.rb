require 'test_helper'
require 'base64'

class ArticleCardsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @tenant = Tenant.create!(name: 'Apresentações', slug: 'apresentacoes', primary: true)
    @tenant.create_site_setting!(professional_name: 'Apresentações')
    @user = @tenant.users.create!(email: 'teasers@example.test', password: 'Teaser-password-123!', admin: true)
    @contents = @tenant.pages.create!(name: 'Conteúdos', slug: 'conteudos')
    @highlights = @contents.sections.create!(section_type: 'cards', title: 'Destaques', anchor: 'destaques')
    @articles = @contents.sections.create!(section_type: 'cards', title: 'Artigos', anchor: 'artigos')
    sign_in @user
  end

  test 'new articles automatically create a teaser in the selected contents area' do
    get new_admin_article_path
    assert_select 'select[name=card_section] option[value=?]', @highlights.id.to_s
    post admin_articles_path, params: { card_section: @highlights.id, page: { name: 'O texto da autora', content_kind: 'article', description: 'Uma breve apresentação.', description_en: 'A short introduction.' } }
    assert_response :redirect
    article = @tenant.pages.editorial.last
    card = article.linking_cards.first
    assert_equal @highlights.id, card.section_id
    assert_equal 'Uma breve apresentação.', card.body
    assert_equal 'A short introduction.', card.body_en
    assert_equal article.name, card.title
    assert_equal @contents.id, card.section.page_id
    assert_not article.published?
    assert_no_difference 'SectionItem.count' do
      ArticleCardService.new(article: article).save!
    end
    get edit_admin_article_card_path(article)
    assert_response :success
    assert_select '.article-card-preview .compact-card__link', text: /Saiba mais/
    assert_select '.article-card-preview a[href=?]', admin_page_preview_path(article, locale: 'pt-BR')
  end

  test 'cards move and change independently while published snapshots and full text remain untouched' do
    article = create_article
    service = ArticleCardService.new(article: article)
    card = service.save!
    PagePublicationService.new(page: @contents).call
    post_body = article.sections.draft.find_by!(section_type: 'text').body
    patch admin_article_card_path(article), params: { card_section: @highlights.id, article_card: { title: 'Título da chamada', body: 'Resumo escolhido pela autora.', body_en: 'Chosen summary.', visible: true } }
    assert_redirected_to edit_admin_article_card_path(article, locale: 'pt-BR')
    assert_equal @highlights.id, card.reload.section_id
    assert_equal 'Resumo escolhido pela autora.', card.body
    assert_equal post_body, article.sections.draft.find_by!(section_type: 'text').body
    assert_not_equal card.body, article.linking_cards.joins(:section).find_by!(sections: { publication_state: 'published' }).body
    get edit_admin_article_card_path(article)
    assert_select '.article-card-preview .compact-card__body', text: /Resumo escolhido pela autora/
    assert_select '.article-card-preview .compact-card__title', text: 'Título da chamada'
  end

  test 'published teaser and Saiba mais open the full article without exposing the full text on the listing' do
    article = create_article
    card = ArticleCardService.new(article: article).save!(attributes: { body: 'Resumo breve. ' * 50 })
    PagePublicationService.new(page: article).call
    PagePublicationService.new(page: @contents).call
    sign_out @user
    get public_page_path(slug: 'conteudos', site_slug: @tenant.slug)
    assert_response :success
    assert_select '.compact-card__body' do |nodes|
      assert_operator nodes.first.text.strip.length, :<=, 240
    end
    assert_not_includes response.body, 'Este é o conteúdo integral produzido pela autora.'
    assert_select '.compact-card--linked .compact-card__link[href=?]', public_page_path(slug: article.slug, site_slug: @tenant.slug, locale: 'pt-BR'), text: /Saiba mais/
    assert_select '.compact-card--linked dialog', count: 0
    get public_page_path(slug: article.slug, site_slug: @tenant.slug)
    assert_includes response.body, 'Este é o conteúdo integral produzido pela autora.'
  end

  test 'existing articles can get a card with their cover and a safe short summary without duplication' do
    article = create_article
    heading = article.sections.draft.find_by!(section_type: 'hero')
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jhXkAAAAASUVORK5CYII=')
    heading.image.attach(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    service = ArticleCardService.new(article: article)
    assert_no_difference ['Page.count', 'SectionItem.count'] do
      get edit_admin_article_card_path(article)
      assert_response :success
    end
    card = service.save!
    assert_equal heading.image.blob_id, card.image.blob_id
    assert_equal article.sections.draft.find_by!(section_type: 'text').body, card.body
    card.update!(body: 'Resumo personalizado')
    assert_no_difference 'SectionItem.count' do
      assert_equal card.id, service.save!.id
    end
    assert_equal 'Resumo personalizado', card.reload.body
  end

  test 'a reflection gets its own section when necessary and no other page is published implicitly' do
    post admin_articles_path, params: { page: { name: 'Reflexão', content_kind: 'reflection' } }
    article = @tenant.pages.editorial.last
    card = article.linking_cards.first
    assert_equal 'reflexoes', card.section.anchor
    assert_equal @contents.id, card.section.page_id
    assert_not @contents.reload.published?
    assert_equal 0, @contents.sections.published.count
  end

  test 'empty summaries follow the article body without leaking unpublished text' do
    article = create_article
    ArticleCardService.new(article: article).save!(attributes: { body: '', body_en: '' })
    PagePublicationService.new(page: article).call
    PagePublicationService.new(page: @contents).call
    article.sections.draft.find_by!(section_type: 'text').update!(body: 'Trecho novo ainda em rascunho.')
    sign_out @user
    get public_page_path(slug: 'conteudos')
    assert_select '.compact-card__body', text: /Este é o conteúdo integral produzido pela autora/
    assert_not_includes response.body, 'Trecho novo ainda em rascunho.'
    sign_in @user
    get admin_page_preview_frame_path(@contents)
    assert_select '.compact-card__body', text: /Trecho novo ainda em rascunho/
  end

  test 'a client without a contents page gets a draft listing when creating the first article' do
    @contents.destroy!
    post admin_articles_path, params: { page: { name: 'Primeiro artigo', content_kind: 'article', description: 'Um resumo.' } }
    assert_response :redirect
    listing = @tenant.pages.find_by!(slug: 'conteudos')
    assert_not listing.published?
    article = @tenant.pages.editorial.last
    assert_equal listing.id, article.linking_cards.first.section.page_id
    assert_equal 'artigos', article.linking_cards.first.section.anchor
  end

  test 'foreign and published sections cannot receive cards and invalid input rolls back' do
    article = create_article
    card = ArticleCardService.new(article: article).save!
    other = Tenant.create!(name: 'Outro', slug: 'outro-apresentacao')
    foreign_article = other.pages.create!(name: 'Segredo', content_kind: 'article')
    foreign_section = foreign_article.sections.create!(section_type: 'cards')
    PagePublicationService.new(page: @contents).call
    [foreign_section.id, @contents.sections.published.first.id, 'new:invalid'].each do |section_id|
      patch admin_article_card_path(article), params: { card_section: section_id, article_card: { title: 'Inválido' } }
      assert_response :not_found
    end
    assert_equal @articles.id, card.reload.section_id
    get edit_admin_article_card_path(foreign_article)
    assert_response :not_found
    assert_no_difference 'Page.count' do
      post admin_articles_path, params: { card_section: foreign_section.id, page: { name: 'Não pode ser criado', content_kind: 'article' } }
      assert_response :not_found
    end
    patch admin_article_card_path(article), params: { card_section: @highlights.id, article_card: { title: '' } }
    assert_response :unprocessable_entity
    assert_equal @articles.id, card.reload.section_id
    assert_equal article.name, card.title
  end

  private

  def create_article
    article = @tenant.pages.create!(name: 'Texto completo', content_kind: 'article')
    article.sections.create!(section_type: 'hero', title: article.name, title_en: 'Full text')
    article.sections.create!(section_type: 'text', position: 2, body: 'Este é o conteúdo integral produzido pela autora.')
    article
  end
end
