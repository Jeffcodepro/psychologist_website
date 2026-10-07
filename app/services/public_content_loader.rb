# Batch-load the published tree without fetching drafts or issuing one query per card.
class PublicContentLoader
  def self.sections(page)
    page.published_sections.preload(
      :page,
      image_attachment: :blob,
      banner_attachment: :blob, video_attachment: :blob, banner_video_attachment: :blob,
      section_slides: { image_attachment: :blob, video_attachment: :blob },
      section_items: [ { image_attachment: :blob, video_attachment: :blob }, { linked_page: :published_sections } ]
    )
  end
end
