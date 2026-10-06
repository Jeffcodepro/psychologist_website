require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  def select(value, from: nil, **options)
    field = first(:field, from, **options, visible: :all, wait: 0, minimum: 0)
    unless field
      label = find('label', text: from, exact_text: true)
      control = page.document.find_by_id(label[:for])
      field = control.find(:xpath, 'ancestor::*[contains(@class,"ts-wrapper")]/preceding-sibling::select', visible: :all)
    end
    return super unless field.evaluate_script("Boolean(this.tomselect)")
    choose_select_option(field, value)
  end

  def choose_select_option(field, value)
    control = field.find(:xpath, 'following-sibling::*[contains(@class,"ts-wrapper")]').find('.ts-control')
    control.click
    menu = page.document.find('.selection-menu', visible: true)
    menu.find('.dropdown-input').set(value)
    menu.find('.option[data-selectable]', text: value, exact_text: true).click
  end
end
