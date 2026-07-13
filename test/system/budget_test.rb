require "application_system_test_case"

class BudgetTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(email: "system@example.com", password: "password123")
    @user.confirm!
  end

  def login
    visit login_url
    fill_in "user[email]", with: @user.email
    fill_in "user[password]", with: "password123"
    click_button "Sign In"
    assert_text "Welcome back"
  end

  test "deleting a budget row via the styled confirm dialog" do
    with_flake_diagnostics do
      login
      visit budget_url
      assert_selector "tr", text: "Rates"
      arm_event_trace

      row = find("tr", text: "Rates", match: :first)
      row.find("button", text: "✕").click

      within("dialog") { click_button "Confirm" }

      assert_no_selector "tr", text: "Rates"
      assert_not @user.budget_items.exists?(name: "Rates")
    end
  end

  test "editing an amount recalculates totals in place" do
    with_flake_diagnostics do
      login
      visit budget_url
      field = find_by_id("amount_budget_item_#{@user.budget_items.find_by!(name: "Rent").id}")
      arm_event_trace
      field.fill_in with: "335"
      field.send_keys :tab
      assert_text "1,451.67"
    end
  end

  private

  # TEMPORARY: diagnostics for an intermittent CI-only flake where Turbo form
  # submissions (inline edit, delete dialog) appear to do nothing.
  def arm_event_trace
    page.execute_script(<<~JS)
      window.__events = [];
      const log = (name, detail) => window.__events.push(name + (detail ? " " + detail : ""));
      addEventListener("click", (e) => log("click", e.target.tagName + "." + (e.target.className || "").slice(0, 40)), true);
      addEventListener("change", (e) => log("change", e.target.id), true);
      addEventListener("focusin", (e) => log("focusin", e.target.id || e.target.tagName), true);
      addEventListener("input", (e) => log("input", e.target.id + "=" + (e.target.value || "")), true);
      addEventListener("keydown", (e) => log("keydown", e.key), true);
      addEventListener("submit", (e) => log("submit", (e.target.action || "") + " prevented=" + e.defaultPrevented), true);
      ["turbo:submit-start", "turbo:submit-end", "turbo:before-fetch-request",
       "turbo:before-fetch-response", "turbo:fetch-request-error", "turbo:visit",
       "turbo:before-render", "turbo:render", "turbo:morph"].forEach((n) =>
        addEventListener(n, (e) => log(n, e.detail?.success ?? "")));
      addEventListener("error", (e) => log("JS-ERROR", e.message));
      addEventListener("unhandledrejection", (e) => log("UNHANDLED-REJECTION", String(e.reason)));
    JS
  end

  def with_flake_diagnostics
    yield
  rescue Exception => e
    puts "=== FLAKE DIAGNOSTICS ==="
    puts "error: #{e.class}: #{e.message.lines.first}"
    puts "ready state: #{page.evaluate_script("document.readyState") rescue $!}"
    puts "turbo loaded: #{page.evaluate_script("!!window.Turbo") rescue $!}"
    puts "confirm dialog ready: #{page.evaluate_script("!!window.__confirmDialogReady") rescue $!}"
    puts "chartkick loaded: #{page.evaluate_script("!!window.Chartkick") rescue $!}"
    puts "dialog in dom: #{page.evaluate_script("!!document.querySelector('dialog')") rescue $!}"
    logs = begin
      page.driver.browser.logs.get(:browser).map { |l| "#{l.level}: #{l.message}" }
    rescue StandardError => log_err
      ["console logs unavailable: #{log_err.message}"]
    end
    puts "console:", logs
    puts "event trace: #{page.evaluate_script("window.__events") rescue $!}"
    puts "active element: #{page.evaluate_script("document.activeElement && (document.activeElement.id || document.activeElement.tagName)") rescue $!}"
    puts "rent field value: #{page.evaluate_script("(document.querySelector('[id^=amount_budget_item_]') || {}).value") rescue $!}"
    puts "window handles: #{page.driver.browser.window_handles.size rescue $!}"
    log_file = Rails.root.join("log/test.log")
    puts "--- last requests in test.log ---"
    puts File.readlines(log_file).last(60).join if File.exist?(log_file)
    puts "========================="
    raise
  end
end
