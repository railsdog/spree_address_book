module Spree::AddressesHelper
  def address_field(form, method, address_id = "b", &handler)
    content_tag :div, :id => [address_id, method].join, :class => "field form-group" do
      if handler
        handler.call
      else
        is_required = Spree::Address.required_fields.include?(method)
        separator = is_required ? '<span class="required">*</span>' : ''
        form.label(method) + separator.html_safe +
          form.text_field(method, :class => is_required ? 'required form-control input-sm' : 'form-control input-sm')
      end
    end
  end

  def address_state(form, country, address_id)
    country ||= Spree::Country.includes(:states).find(Spree::Config[:default_country_id])
    have_states = !country.states.empty?
    state_elements = [
      form.collection_select(
        :state_id,
        country.states.order(:name),
        :id,
        :name,
        {:include_blank => true},
        {
          class: have_states ? "required form-control input-sm" : "hidden form-control input-sm",
          disabled: !have_states
        }
      ),

      form.text_field(
        :state_name,
        class: !have_states ? "required form-control input-sm" : "hidden form-control input-sm",
        disabled: have_states
      )
    ].join.gsub('"', "'").gsub("\n", "")

    form.label(:state_id, Spree.t(:state)) +
      %Q(<span class="required" id="#{address_id}state-required">*</span>).html_safe +
      content_tag(:noscript, form.text_field(:state_name, :class => 'required')) +
      javascript_tag("document.write(\"#{state_elements.html_safe}\");")
  end
end
