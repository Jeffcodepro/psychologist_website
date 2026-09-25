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
        .ordered
  end

  def new
    @section_item =
      @section.section_items.new(
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

    if @section_item.save
      redirect_to(
        admin_page_section_section_items_path(
          @page,
          @section
        ),
        notice: "Card criado com sucesso."
      )
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @section_item.update(
      section_item_params
    )
      redirect_to(
        admin_page_section_section_items_path(
          @page,
          @section
        ),
        notice: "Card atualizado com sucesso."
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
        @section
      ),
      notice: "Card removido."
    )
  end

  private

  def set_page
    @page =
      Page.find(
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
        :title,
        :body,
        :title_en,
        :body_en,
        :position,
        :visible,
        :image
      )
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
