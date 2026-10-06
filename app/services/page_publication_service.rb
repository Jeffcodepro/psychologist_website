class PagePublicationService
  def initialize(page:)
    @page = page
  end

  def call
    @page.with_lock do
      remove_current_publication
      publish_sections

      publication_time = Time.current
      @page.update!(
        published: true,
        published_at: (@page.published_at if @page.editorial?) || publication_time,
        updated_at: publication_time
      )
    end
  end

  private

  # --------------------------------------------------
  # REMOVE CURRENT PUBLISHED VERSION
  # --------------------------------------------------

  def remove_current_publication
    @page.sections
         .published
         .destroy_all
  end

  # --------------------------------------------------
  # PUBLISH DRAFT SECTIONS
  # --------------------------------------------------

  def publish_sections
    @page.sections
         .draft
         .order(:position, :id)
         .each do |draft_section|

      published_section =
        duplicate_section(draft_section)

      copy_attachment(
        source: draft_section,
        target: published_section,
        attachment_name: :image
      )

      copy_attachment(
        source: draft_section,
        target: published_section,
        attachment_name: :banner
      )

      draft_section.section_slides.ordered.each do |slide|
        copy = slide.dup
        copy.section = published_section
        copy.image.attach(slide.image.blob) if slide.image.attached?
        copy.save!
      end

      copy_items(
        source_section: draft_section,
        target_section: published_section
      )
    end
  end

  # --------------------------------------------------
  # DUPLICATE SECTION
  # --------------------------------------------------

  def duplicate_section(draft_section)
    published_section =
      draft_section.dup

    published_section.publication_state =
      "published"

    # Removing a destination must not prevent another page from publishing.
    published_section.action_buttons = draft_section.action_buttons.reject do |button|
      button['action'] == 'section' &&
        !@page.tenant.sections.draft.exists?(navigation_key: button['value'])
    end

    published_section.save!

    published_section
  end

  # --------------------------------------------------
  # COPY SECTION ITEMS
  # --------------------------------------------------

  def copy_items(
    source_section:,
    target_section:
  )
    source_section
      .section_items
      .order(:position, :id)
      .each do |draft_item|

      published_item =
        target_section
          .section_items
          .create!(
            draft_item.attributes.except(
              "id",
              "section_id",
              "created_at",
              "updated_at"
            )
          )

      copy_attachment(
        source: draft_item,
        target: published_item,
        attachment_name: :image
      )
    end
  end

  # --------------------------------------------------
  # COPY ACTIVE STORAGE ATTACHMENT
  # --------------------------------------------------

  def copy_attachment(
    source:,
    target:,
    attachment_name:
  )
    source_attachment =
      source.public_send(
        attachment_name
      )

    return unless source_attachment.attached?

    target_attachment =
      target.public_send(
        attachment_name
      )

    target_attachment.attach(
      source_attachment.blob
    )
  end
end
