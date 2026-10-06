class SitePublicationService
  def initialize(tenant:, page_ids:)
    @tenant, @page_ids = tenant, Array(page_ids).map(&:to_s).uniq
  end

  def call
    @tenant.with_lock do
      pages = @tenant.pages.where(id: @page_ids).order(:id).to_a
      raise ActiveRecord::RecordNotFound if pages.empty? || pages.map { |page| page.id.to_s }.sort != @page_ids.sort
      pages.each { |page| PagePublicationService.new(page: page).call }
      pages.length
    end
  end
end
