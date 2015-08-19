shared_context "support helper" do

  private

  # Disables JS confirmation popups in feature tests.
  def bypass_js_confirm
    page.evaluate_script('window.confirm = function() { return true; }')
  end

end
