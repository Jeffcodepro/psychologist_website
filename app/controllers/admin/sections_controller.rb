class Admin::SectionsController < Admin::BaseController
  before_action :set_page
  before_action :set_section, only: %i[
    edit
    update
    destroy
    clear_field
    layout_preview
  ]

  def index
    @sections = @page
      .sections
      .draft
      .ordered
  end

  def new
    @section = @page.sections.new(
      publication_state: "draft",
      position: next_position,
      section_type: params[:preset] == "buttons" ? "cta" : "text",
      action_buttons: params[:preset] == "buttons" ? [{ label: "Saiba mais", action: "contact", value: "", style: "primary" }] : [],
      image_shape: "rounded",
      media_layout: "text_left",
      media_size: "medium",
      banner_layout: "top"
    )
  end

  def create
    @section = @page.sections.new(section_params)
    @section.publication_state = "draft"
    @section.position ||= next_position

    if @section.save
      redirect_to(
        admin_page_sections_path(@page),
        notice: "Bloco criado com sucesso."
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @section.update(section_params)
      respond_to do |format|
        format.html do
          redirect_to(
            safe_preview_return_path ||
              edit_admin_page_section_path(@page, @section),
            notice: "Rascunho salvo."
          )
        end

        format.json do
          render json: {
            success: true,
            media_layout: @section.effective_media_layout,
            media_size: @section.effective_media_size,
            image_shape: @section.effective_image_shape,
            banner_layout: @section.effective_banner_layout,
            media_layouts: %w[desktop tablet mobile].index_with { |device| helpers.section_media_layout(@section, device) },
            style_variables: helpers.section_style_variables(@section),
            banner_tablet: @section.visual_value("banner_layout", "tablet"),
            banner_mobile: @section.visual_value("banner_layout", "mobile")
          }
        end
      end
    else
      respond_to do |format|
        format.html do
          render :edit, status: :unprocessable_entity
        end

        format.json do
          render json: {
            success: false,
            errors: @section.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    Section.transaction do
      @section.destroy!
      normalize_positions
    end

    redirect_to(
      safe_preview_return_path || admin_page_sections_path(@page),
      notice: "Bloco removido.",
      status: :see_other
    )
  end

  def swap_positions
    @page.with_lock do
      sections = @page.sections.draft.ordered.to_a
      first = sections.find { |section| section.id.to_s == params[:first_id].to_s }
      second = sections.find { |section| section.id.to_s == params[:second_id].to_s }
      raise ActiveRecord::RecordNotFound unless first && second

      # Normalize legacy duplicate positions and change only ordering metadata.
      # Unrelated content validation must not prevent moving an existing block.
      first_index, second_index = sections.index(first), sections.index(second)
      sections[first_index], sections[second_index] = second, first
      sections.each_with_index do |section, index|
        section.update_columns(position: index + 1, updated_at: Time.current)
      end
    end

    redirect_after_change
  end

  def layout_preview
    fields = SectionLayout::DEFAULTS.keys + %w[media_layout media_size image_shape text_order buttons_position buttons_alignment title body title_en body_en section_type]
    preview = params.fetch(:section, ActionController::Parameters.new).permit(*fields,
      responsive_settings: { tablet: fields, mobile: fields })
    @section.assign_attributes(preview)
    unless @section.valid?
      render plain: "Confira os valores de espaçamento e aparência.", status: :unprocessable_entity
      return
    end
    @site_setting = current_tenant.site_setting
    render "admin/sections/layout_preview", layout: "section_spacing_preview"
  end

  def swap_fields
    source = @page.sections.draft.find(params[:source_id])
    target = @page.sections.draft.find(params[:target_id])
    field = params[:field].to_s

    case field
    when "title", "body"
      swap_text_fields(source, target, field)
    when "buttons"
      source_buttons, target_buttons = source.action_buttons, target.action_buttons
      Section.transaction do
        source.update!(action_buttons: target_buttons)
        target.update!(action_buttons: source_buttons)
      end
    when "image", "banner"
      swap_attachment(source, target, field)
    else
      head :unprocessable_entity
      return
    end

    redirect_after_change
  end

  def clear_field
    field = params[:field].to_s

    case field
    when "title"
      @section.update!(title: nil)
    when "body"
      @section.update!(body: nil)
    when "title_en"
      @section.update!(title_en: nil)
    when "body_en"
      @section.update!(body_en: nil)
    when "image", "banner"
      Section.transaction do
        @section.public_send(field).attachment&.destroy!
        @section.media_video_attachment(field).attachment&.destroy!
        @section.update!(video_settings: @section.video_settings.except(field))
      end
    else
      head :unprocessable_entity
      return
    end

    redirect_after_change
  end

  private

  def set_page
    @page = current_tenant.pages.find(params[:page_id])
  end

  def set_section
    if action_name == "layout_preview" && params[:id].blank?
      @section = @page.sections.new(section_type: "text", position: next_position)
      return
    end
    @section = @page
      .sections
      .draft
      .find(params[:id])
  end

  def section_params
    permitted = params
      .require(:section)
      .permit(
        :section_type,
        *SectionLayout::DEFAULTS.keys,
        *SectionMediaOverlay::FIELDS,
        :form_fields_json, :action_buttons_json, :buttons_position, :buttons_alignment,
        :title,
        :title_en,
        :body,
        :body_en,
        :position,
        :visible,
        :anchor,
        :show_in_nav,
        :nav_label,
        :nav_label_en,
        :title_font_family,
        :title_font_weight, :title_font_style, :title_line_height, :title_letter_spacing,
        :body_font_weight, :body_font_style, :body_line_height, :body_letter_spacing,
        :body_font_family,
        :title_font_size_desktop,
        :title_font_size_mobile,
        :body_font_size_desktop,
        :body_font_size_mobile,
        :text_alignment,
        :title_alignment,
        :body_alignment,
        :text_order,
        :text_theme,
        :title_color,
        :body_color,
        :accent_color,
        :background_color,
        :overlay_color,
        :banner_position,
        :banner_overlay,
        :content_vertical_position,
        :image_position_x,
        :image_position_y,
        :banner_position_x,
        :banner_position_y,
        :image_zoom,
        :banner_zoom,
        :image_shape,
        :media_layout,
        :media_size,
        :video, :banner_video, :remove_video, :remove_banner_video,
        :banner_layout,
        :image,
        :banner,
        :remove_image,
        :remove_banner,
        :cards_orientation,
        :cards_placement,
        :cards_alignment,
        :media_interval_seconds,
        :use_profile_image,
        :cards_wrap,
        :cards_columns_desktop,
        :cards_columns_tablet,
        :cards_columns_mobile,
        :cards_autoplay,
        :cards_autoplay_seconds,
        video_settings: VideoMedia::PARAMS,
        media_adjustments: MediaAdjustable::PARAMS,
        section_slides_attributes: [:id, :role, :position, :image, :image_position_x, :image_position_y,
          :image_zoom, :image_shape, :video, :remove_video, :_destroy, { video_settings: VideoMedia::PARAMS, media_adjustments: MediaAdjustable::PARAMS }],
        responsive_settings: {
          tablet: ResponsiveSection::FIELDS,
          mobile: ResponsiveSection::FIELDS
        }
      )

    if permitted[:responsive_settings] && @section&.persisted?
      permitted[:responsive_settings] = @section.responsive_settings.deep_merge(
        permitted[:responsive_settings].to_h
      )
    end
    permitted
  end

  def next_position
    @page
      .sections
      .draft
      .maximum(:position)
      .to_i + 1
  end

  def normalize_positions
    @page
      .sections
      .draft
      .ordered
      .each_with_index do |section, index|
        section.update_column(:position, index + 1)
      end
  end

  def swap_text_fields(source, target, field)
    fields = [field, "#{field}_en"]
    source_values = source.attributes.slice(*fields)
    target_values = target.attributes.slice(*fields)
    Section.transaction do
      source.update!(target_values)
      target.update!(source_values)
    end
  end

  def swap_attachment(source, target, field)
    Section.transaction do
      source_attachment = source.public_send(field)
      target_attachment = target.public_send(field)
      source_blob = source_attachment.blob if source_attachment.attached?
      target_blob = target_attachment.blob if target_attachment.attached?
      source_slides = source.section_slides.where(role: field).to_a
      target_slides = target.section_slides.where(role: field).to_a
      source_attachment.detach if source_attachment.attached?
      target_attachment.detach if target_attachment.attached?
      source_attachment.attach(target_blob) if target_blob
      target_attachment.attach(source_blob) if source_blob
      source_slides.each { |slide| slide.update!(section: target) }
      target_slides.each { |slide| slide.update!(section: source) }
      video_name = field == "banner" ? :banner_video : :video
      source_video = source.public_send(video_name).blob if source.public_send(video_name).attached?
      target_video = target.public_send(video_name).blob if target.public_send(video_name).attached?
      source.public_send(video_name).detach
      target.public_send(video_name).detach
      source.public_send("#{video_name}=", target_video)
      target.public_send("#{video_name}=", source_video)
      source_video_settings = source.video_settings.deep_dup
      source.video_settings = source.video_settings.merge(field => target.video_settings.fetch(field, {}))
      target.video_settings = target.video_settings.merge(field => source_video_settings.fetch(field, {}))
      fields = %W[#{field}_position_x #{field}_position_y #{field}_zoom]
      fields += %w[image_shape use_profile_image] if field == "image"
      source_values = source.attributes.slice(*fields)
      target_values = target.attributes.slice(*fields)
      source_adjustments = source.media_adjustments.deep_dup
      target_adjustments = target.media_adjustments.deep_dup
      source.update!(target_values.merge(media_adjustments: source_adjustments.merge(field => target_adjustments.fetch(field, {}))))
      target.update!(source_values.merge(media_adjustments: target_adjustments.merge(field => source_adjustments.fetch(field, {}))))
    end
  end

  def redirect_after_change
    return head :no_content if request.format.json?

    redirect_to(
      safe_preview_return_path ||
        admin_page_preview_path(@page)
    )
  end
end
