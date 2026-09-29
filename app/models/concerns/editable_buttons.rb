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
          errors.add(attribute, "verifique o texto e o destino dos botões") unless ActionButtonSchema.valid?(public_send(attribute), tenant: tenant)
        end
      end
    end
  end
end
