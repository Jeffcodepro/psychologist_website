require "test_helper"

class Admin::EditorialEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tenant = Tenant.create!(name: "Escrita", slug: "escrita", primary: true)
    @tenant.create_site_setting!(professional_name: "Autora")
    @user = @tenant.users.create!(admin: true, email: "writing@example.test", password: "Writing-password-123!")
    sign_in @user
  end

  test "article can be written translated edited and published without using the generic block editor" do
    get new_admin_article_path
    assert_response :success
    assert_select 'textarea[name="article_content[body]"]'
    assert_select 'input[name="page[show_in_nav]"]', count: 0
    assert_select 'input[name="page[position]"]', count: 0
    post admin_articles_path, params: { page: { name: "Comunicação", content_kind: "article" }, article_content: {
      title_en: "Communication", body: "É importante **comunicar**.\n\n## Com respeito\n\n- Escuta\n- Clareza", body_en: "**Communicate** with respect." } }
    article = @tenant.pages.editorial.last
    assert_redirected_to edit_admin_article_path(article)
    follow_redirect!
    assert_response :success
    assert_select 'textarea[name="article_content[body]"]', text: /\*\*comunicar\*\*/
    card = article.linking_cards.first
    assert_not_includes card.body, "**"
    assert_includes card.body, "comunicar"
    assert_equal "Communication", article.sections.draft.find_by!(section_type: "hero").title_en
    PagePublicationService.new(page: article).call
    patch admin_article_path(article), params: { page: { name: "Comunicação revisada" }, article_content: { body: "Novo **rascunho**." } }
    assert_response :see_other
    assert_includes article.sections.published.find_by!(section_type: "text").body, "comunicar"
    assert_equal "Novo **rascunho**.", article.sections.draft.find_by!(section_type: "text").body
    assert_equal "**Communicate** with respect.", article.sections.draft.find_by!(section_type: "text").body_en
    sign_out @user
    get public_page_path(slug: article.slug, site_slug: @tenant.slug)
    assert_select '.section-body strong', text: 'comunicar'
    assert_select '.section-body h2', text: 'Com respeito'
    assert_select '.section-body ul li', count: 2
    assert_not_includes response.body, 'Novo <strong>rascunho'
  end

  test "legacy articles use their populated block and keep other blocks and custom cards" do
    article = @tenant.pages.create!(name: "Antigo", content_kind: "article")
    article.sections.create!(section_type: "hero", title: "Antigo", position: 1)
    empty = article.sections.create!(section_type: "text", position: 2)
    body = article.sections.create!(section_type: "text", body: "Texto já escrito", position: 3)
    extra = article.sections.create!(section_type: "text", body: "Conclusão preservada", position: 4)
    card = ArticleCardService.new(article: article).save!(attributes: { body: "Resumo personalizado" })
    get edit_admin_article_path(article)
    assert_select 'textarea[name="article_content[body]"]', text: "Texto já escrito"
    assert_select 'a', text: 'Ajustar blocos e imagens', minimum: 1
    assert_no_difference ['Section.count', 'SectionItem.count'] do
      patch admin_article_path(article), params: { page: { name: "Revisado" }, article_content: { body: "" } }
    end
    assert_equal "", body.reload.body
    assert_nil empty.reload.body
    assert_equal "Conclusão preservada", extra.reload.body
    assert_equal "Resumo personalizado", card.reload.body
    get edit_admin_article_path(article)
    assert_select 'textarea[name="article_content[body]"]', text: ""
    get edit_admin_page_path(article)
    assert_redirected_to edit_admin_article_path(article)
  end

  test "validation preserves entered text and never creates orphan blocks or cards" do
    assert_no_difference ['Page.count', 'Section.count', 'SectionItem.count'] do
      post admin_articles_path, params: { page: { name: "", content_kind: "article" }, article_content: { body: "Não perder este texto" } }
      assert_response :unprocessable_entity
    end
    assert_select 'textarea[name="article_content[body]"]', text: "Não perder este texto"
  end

  test "foreign pages and published content cannot be changed with editorial parameters" do
    other = Tenant.create!(name: "Outro", slug: "outro-texto")
    foreign = other.pages.create!(name: "Privado", content_kind: "article")
    get edit_admin_article_path(foreign)
    assert_response :not_found
    patch admin_article_path(foreign), params: { page: { name: "Alterado" } }
    assert_response :not_found
    assert_equal "Privado", foreign.reload.name
    page = @tenant.pages.create!(name: "Página normal")
    get edit_admin_article_path(page)
    assert_response :not_found
  end

  test "formatted preview sanitizes scripts attributes and unsafe links and is authenticated" do
    post admin_text_preview_path, params: { text: '**Forte** <script>alert(1)</script><a href="javascript:alert(1)" onclick="bad()">link</a><img src=x onerror=bad()>' }, as: :json
    assert_response :success
    html = response.parsed_body.fetch('html')
    assert_includes html, '<strong>Forte</strong>'
    %w[<script onclick onerror javascript: <img].each { |unsafe| assert_not_includes html, unsafe }
    post admin_text_preview_path, params: { text: 'x' * 200_001 }, as: :json
    assert_response :content_too_large
    sign_out @user
    post admin_text_preview_path, params: { text: '**Teste**' }, as: :json
    assert_response :not_found
  end
end
