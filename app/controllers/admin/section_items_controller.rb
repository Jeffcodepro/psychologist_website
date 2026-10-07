class Admin::SectionItemsController < Admin::BaseController
  before_action :set_page
  before_action :set_section
  before_action :set_section_item,
                only: %i[
                  edit
                  update
                  destroy
                ]

  def index
    @section_items =
      @section
        .section_items
        .where(item_kind: requested_kind)
        .ordered
  end

  def new
    @section_item =
      @section.section_items.new(
        item_kind: requested_kind,
        visible: true,
        position: next_position
      )
  end

  def create
    @section_item =
      @section.section_items.new(
        section_item_params
      )

    @section_item.position =
      next_position if @section_item.position.blank?

    if save_section_item
      redirect_to(
        @article ? edit_admin_article_path(@article) : after_save_path,
        notice: "Conteúdo criado com sucesso."
      )
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @section_item.assign_attributes(section_item_params)
    if save_section_item
      redirect_to(
        @article ? edit_admin_article_path(@article) : after_save_path,
        notice: "Conteúdo atualizado com sucesso."
      )
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def destroy
    @section_item.destroy!

    normalize_positions

    redirect_to(
      admin_page_section_section_items_path(
        @page,
        @section, kind: @section_item.item_kind
      ),
      notice: "Conteúdo removido.",
      status: :see_other
    )
  end

  private

  def save_section_item
    SectionItem.transaction do
      @section_item.save!
      @article = ArticleFromCardService.call(card: @section_item) if params[:write_article] == '1'
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    @section_item.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @section_item
    false
  end

  def set_page
    @page =
      current_tenant.pages.find(
        params[:page_id]
      )
  end

  def set_section
    @section =
      @page
        .sections
        .draft
        .find(
          params[:section_id]
        )
  end

  def set_section_item
    @section_item =
      @section
        .section_items
        .find(
          params[:id]
        )
  end

  def section_item_params
    params
      .require(:section_item)
      .permit(
        :item_kind,
        :linked_page_id,
        :title,
        :body,
        :title_en,
        :body_en,
        :position,
        :visible,
        :image, :video, :remove_video,
        :remove_image,
        :image_position_x,
        :image_position_y,
        :image_zoom,
        :image_shape,
        video_settings: VideoMedia::PARAMS, card_settings: CardPresentation::PARAMS, media_adjustments: MediaAdjustable::PARAMS
      )
  end

  def after_save_path
    return admin_page_preview_path(@page) if params[:from_preview] == "1"
    admin_page_section_section_items_path(@page, @section, kind: @section_item.item_kind)
  end

  def requested_kind
    return params[:kind] if SectionItem::KINDS.include?(params[:kind])
    { "faq" => "question", "gallery" => "gallery" }.fetch(@section.section_type, "card")
  end

  def next_position
    last_position =
      @section
        .section_items
        .maximum(:position)

    last_position.to_i + 1
  end

  def normalize_positions
    @section
      .section_items
      .ordered
      .each_with_index do |item, index|

      item.update_column(
        :position,
        index + 1
      )
    end
  end
end
