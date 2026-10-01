require "application_system_test_case"
require "base64"

class ImageCropperTest < ApplicationSystemTestCase
  include Warden::Test::Helpers
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]

  setup do
    tenant = Tenant.create!(name: "Enquadramento", slug: "enquadramento", primary: true)
    tenant.create_site_setting!(professional_name: "Enquadramento")
    login_as tenant.users.create!(admin: true, email: "crop@example.test", password: "Crop-test-password-123!")
    @content_page = tenant.pages.create!(name: "Imagens", slug: "imagens")
    @section = @content_page.sections.create!(section_type: "cards", title: "Cards")
    @card = @section.section_items.create!(title: "Imagem de teste", image_shape: "oval")
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=")
    @card.image.attach(io: StringIO.new(png), filename: "crop.png", content_type: "image/png")
  end

  teardown { Warden.test_reset! }

  test "vertical slider makes room to pan and preserves the crop after saving and publication" do
    open_cropper
    assert_equal "1", crop_control("zoom").value
    set_range "y", 75
    assert_equal "1.15", crop_control("zoom").value
    assert_equal "75", crop_control("yField").value
    assert_selector '[data-image-cropper-target="positionHint"]', text: "Zoom ajustado para 115%"

    # At 100% this axis had no overflow; moving it now must visibly shift the image.
    original_top = crop_image_top
    set_range "y", 25
    assert_operator crop_image_top, :>, original_top + 5

    click_button "Salvar card"
    assert_text "Conteúdo atualizado com sucesso."
    assert_equal 25, @card.reload.image_position_y
    assert_equal BigDecimal("1.15"), @card.image_zoom
    open_cropper
    assert_equal "25", crop_control("y").value
    assert_equal "1.15", crop_control("zoom").value

    PagePublicationService.new(page: @content_page).call
    logout
    visit public_page_path(slug: @content_page.slug)
    image = find(".compact-card__image")
    assert_equal "50% 25%", image.evaluate_script("getComputedStyle(this).objectPosition")
    assert_match(/matrix\(1\.15, 0, 0, 1\.15, 0, 0\)/, image.evaluate_script("getComputedStyle(this).transform"))
  end

  test "existing vertical space keeps the chosen zoom and reset does not enlarge the image" do
    @card.update!(image_shape: "rectangle")
    open_cropper
    set_range "y", 80
    assert_equal "1", crop_control("zoom").value
    assert_no_selector '[data-image-cropper-target="positionHint"]'

    set_range "x", 80
    assert_equal "1.15", crop_control("zoom").value
    click_button "Centralizar e redefinir zoom"
    assert_equal "1", crop_control("zoom").value
    assert_equal "50", crop_control("x").value
    assert_equal "50", crop_control("y").value
    assert_no_selector '[data-image-cropper-target="positionHint"]'

    set_range "zoom", 1.7
    set_range "y", 30
    assert_equal "1.7", crop_control("zoom").value
  end

  test "dragging also opens space on a fitted axis and a click alone keeps the original crop" do
    open_cropper
    frame = find('[data-image-cropper-target="frame"]')
    # Finish scrolling before the real mouse gesture; CSS smooth scrolling can
    # otherwise move the frame away from the pointer during Selenium's drag.
    frame.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
    page.driver.browser.action.move_to(frame.native).click.perform
    assert_equal "1", crop_control("zoom").value
    page.driver.browser.action.move_to(frame.native).click_and_hold.move_by(0, 18).release.perform
    assert_equal "1.15", crop_control("zoom").value
    assert_operator crop_control("y").value.to_i, :<, 50
    assert_equal crop_control("y").value, crop_control("yField").value
  end

  test "vertical positioning works in a narrow viewport with keyboard input" do
    page.current_window.resize_to(390, 844)
    open_cropper
    crop_control("y").send_keys(:end)
    assert_equal "100", crop_control("y").value
    assert_equal "100", crop_control("yField").value
    assert_equal "1.15", crop_control("zoomField").value
    assert_selector '[data-image-cropper-target="yLabel"]', text: "100%"
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  private

  def open_cropper
    visit edit_admin_page_section_section_item_path(@content_page, @section, @card)
    assert_selector '[data-image-cropper-target="zoomLabel"]', text: /100%|115%/
    assert_selector '[data-image-cropper-target="dimensions"]', text: "Original: 1 × 1 px"
  end

  def crop_control(target)
    find("[data-image-cropper-target='#{target}']", visible: :all)
  end

  def set_range(target, value)
    crop_control(target).execute_script("this.value = arguments[0]; this.dispatchEvent(new Event('input', { bubbles: true }))", value)
  end

  def crop_image_top
    find('[data-image-cropper-target="image"]').evaluate_script("this.getBoundingClientRect().top")
  end
end
