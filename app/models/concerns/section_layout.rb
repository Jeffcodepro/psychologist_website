module SectionLayout
  extend ActiveSupport::Concern

  BUTTON_POSITIONS = [["Antes dos textos", "before_text"], ["Entre título e parágrafo", "between_text"], ["Depois dos textos", "after_text"],
    ["Acima dos cards / carrossel", "before_cards"], ["Abaixo dos cards / carrossel", "after_cards"]].freeze

  SPACING = {
    "content_gap" => ["Padrão entre elementos", 18, 0..160],
    "title_body_gap" => ["Entre título e texto", nil, 0..160],
    "image_text_gap" => ["Entre imagem e conteúdo", nil, 0..160],
    "buttons_gap" => ["Entre botões e conteúdo", nil, 0..160],
    "cards_content_gap" => ["Entre cards / carrossel e conteúdo", nil, 0..160],
    "form_gap" => ["Entre formulário e conteúdo", nil, 0..160],
    "section_padding_inline" => ["Respiro nas laterais da seção", 0, 0..160],
    "paragraph_spacing" => ["Entre parágrafos", 16, 0..160],
    "section_padding_top" => ["Respiro acima da seção", 44, 0..240],
    "section_padding_bottom" => ["Respiro abaixo da seção", 44, 0..240],
    "column_gap" => ["Padrão entre grupos", 32, 0..160],
    "cards_gap" => ["Entre cards", 20, 0..160]
  }.freeze
  INHERITED_SPACING = {
    "title_body_gap" => "content_gap", "image_text_gap" => "column_gap", "buttons_gap" => "content_gap",
    "cards_content_gap" => "column_gap", "form_gap" => "column_gap"
  }.freeze
  FORM_OPTIONS = {
    "form_position" => ["Posição do formulário", [["Abaixo do texto", "after_text"], ["Acima do texto", "before_text"], ["À esquerda do texto", "left"], ["À direita do texto", "right"]]],
    "form_alignment" => ["Alinhamento do formulário", [["Esquerda", "left"], ["Centro", "center"], ["Direita", "right"]]],
    "form_vertical_alignment" => ["Altura na coluna", [["Topo", "top"], ["Centro", "center"], ["Base", "bottom"]]],
    "form_width" => ["Largura do formulário", [["Compacta · até 480 px", "compact"], ["Média · até 640 px", "medium"], ["Ampla · até 860 px", "wide"], ["Toda a largura disponível", "full"]]]
  }.freeze
  DEFAULTS = SPACING.transform_values { |(_, value, _)| value }.merge("form_position" => "after_text", "form_alignment" => "left", "form_width" => "wide", "form_vertical_alignment" => "top").freeze

  included do
    store_accessor :layout_settings, *DEFAULTS.keys
    SPACING.each do |field, (_, _, range)|
      validates field, numericality: { greater_than_or_equal_to: range.begin, less_than_or_equal_to: range.end }, allow_blank: true
    end
    FORM_OPTIONS.each do |field, (_, options)|
      validates field, inclusion: { in: options.map(&:last) }, allow_blank: true
    end
  end

  DEFAULTS.each do |field, default|
    define_method("effective_#{field}") { public_send(field).presence || default }
  end
end
