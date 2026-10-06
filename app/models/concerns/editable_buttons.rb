module EditableButtons
  extend ActiveSupport::Concern
  class_methods do
    def editable_buttons(*attributes)
      attributes.each do |attribute|
        define_method("#{attribute}_json") { (public_send(attribute).is_a?(Array) ? public_send(attribute) : []).to_json }
        define_method("#{attribute}_json=") do |value|
          public_send("#{attribute}=", JSON.parse(value))
        rescue JSON::ParserError, TypeError
          public_send("#{attribute}=", nil)
        end
        validate do
          # Existing links may outlive a deleted destination. Only newly assigned
          # buttons need destination validation; rendering omits missing targets.
          unchanged_owner = !changes.key?("tenant_id") && !changes.key?("page_id")
          next if persisted? && unchanged_owner && !will_save_change_to_attribute?(attribute)
          errors.add(attribute, "verifique o texto e o destino dos botões") unless ActionButtonSchema.valid?(public_send(attribute), tenant: tenant)
        end
      end
    end
  end
end
