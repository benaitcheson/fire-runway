require "test_helper"

# App-wide security regression suite: authentication boundaries, tenant
# isolation, mass assignment, injection, XSS and token handling.
class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
  end

  # --- Authentication boundary -------------------------------------------

  PROTECTED_GETS = [
    "/", "/dashboard/index", "/user_assets", "/user_liabilities",
    "/budget", "/ai_assistant", "/investment_comparison"
  ].freeze

  test "every protected page redirects logged-out users to login" do
    PROTECTED_GETS.each do |path|
      get path
      assert_redirected_to login_path, "expected #{path} to require login"
    end
  end

  test "mutations require login" do
    post user_assets_url, params: { user_asset: { item_name: "X" } }
    assert_redirected_to login_path

    post budget_items_url, params: { budget_item: { name: "X", section: "bills" } }
    assert_redirected_to login_path

    delete user_asset_url(user_assets(:one))
    assert_redirected_to login_path

    post ai_assistant_chat_url, params: { prompt: "hi" }
    assert_redirected_to login_path
  end

  test "login and sign up remain accessible logged out" do
    get login_url
    assert_response :success
    get sign_up_url
    assert_response :success
  end

  # --- Tenant isolation (IDOR) -------------------------------------------

  test "cannot read, edit, update or destroy another user's asset" do
    sign_in_as @user
    asset = user_assets(:two)

    get user_asset_url(asset)
    assert_response :not_found
    get edit_user_asset_url(asset)
    assert_response :not_found
    patch user_asset_url(asset), params: { user_asset: { item_name: "mine now" } }
    assert_response :not_found
    delete user_asset_url(asset)
    assert_response :not_found
    assert UserAsset.exists?(asset.id)
    assert_equal "Camera", asset.reload.item_name
  end

  test "cannot touch another user's liability" do
    sign_in_as @user
    liability = user_liabilities(:two)

    get user_liability_url(liability)
    assert_response :not_found
    delete user_liability_url(liability)
    assert_response :not_found
    assert UserLiability.exists?(liability.id)
  end

  test "cannot update or destroy another user's budget items" do
    theirs = @other.budget_items.create!(section: "bills", name: "Their rent", amount_cents: 1000, frequency: "weekly")
    sign_in_as @user

    patch budget_item_url(theirs), params: { budget_item: { amount: 999 } }
    assert_response :not_found
    delete budget_item_url(theirs)
    assert_response :not_found
    assert_equal 1000, theirs.reload.amount_cents
  end

  test "index pages only show own records" do
    sign_in_as @user
    get user_assets_url
    assert_response :success
    assert_no_match user_assets(:two).item_name, response.body
  end

  # --- Mass assignment ----------------------------------------------------

  test "cannot assign an asset to another user via user_id param" do
    sign_in_as @user
    post user_assets_url, params: { user_asset: {
      item_name: "Sneaky", purchase_price_cents: 1000, purchase_price_currency: "AUD",
      purchase_date: "2024-01-01", user_id: @other.id
    } }

    asset = UserAsset.find_by(item_name: "Sneaky")
    assert_equal @user.id, asset.user_id
  end

  test "sign up cannot set confirmed_at or id" do
    post sign_up_url, params: { user: {
      email: "massassign@example.com", password: "password123",
      password_confirmation: "password123", confirmed_at: Time.current, id: 424_242
    } }

    user = User.find_by(email: "massassign@example.com")
    assert_not user.confirmed?, "confirmed_at must not be mass-assignable"
    assert_not_equal 424_242, user.id
  end

  # --- Injection ----------------------------------------------------------

  test "asset names containing SQL metacharacters are stored inertly" do
    sign_in_as @user
    name = "Robert'); DROP TABLE users;--"
    post user_assets_url, params: { user_asset: {
      item_name: name, purchase_price_cents: 1000, purchase_price_currency: "AUD",
      purchase_date: "2024-01-01"
    } }

    assert UserAsset.exists?(item_name: name)
    assert User.count.positive?, "users table must survive"
  end

  test "AI asset lookup is safe against SQL injection and LIKE wildcards" do
    executor = Ai::ToolExecutor.new(user: @user)

    result = JSON.parse(executor.execute("get_asset_depreciation", { "name" => "'; DROP TABLE users;--" }))
    assert_match(/No asset matching/, result["error"])
    assert User.count.positive?

    # A bare % must not match everything
    result = JSON.parse(executor.execute("get_asset_depreciation", { "name" => "%" }))
    assert_match(/No asset matching/, result["error"])
  end

  test "AI tools cannot cross user boundaries" do
    executor = Ai::ToolExecutor.new(user: @user)
    result = JSON.parse(executor.execute("list_assets"))
    names = result["assets"].map { |a| a["name"] }
    assert_not_includes names, user_assets(:two).item_name
  end

  # --- XSS ------------------------------------------------------------------

  test "script tags in asset names render escaped" do
    sign_in_as @user
    @user.user_assets.create!(item_name: "<script>alert('xss')</script>",
                              purchase_price_cents: 1000, purchase_price_currency: "AUD",
                              purchase_date: Date.new(2024, 1, 1))

    get user_assets_url
    assert_response :success
    assert_no_match "<script>alert('xss')</script>", response.body
    assert_match "&lt;script&gt;", response.body
  end

  test "script tags in budget item names render escaped" do
    @user.budget_items.create!(section: "bills", name: "<img src=x onerror=alert(1)>",
                               amount_cents: 100, frequency: "weekly")
    sign_in_as @user

    get budget_url
    assert_response :success
    assert_no_match "<img src=x onerror=alert(1)>", response.body
  end

  # --- Confirmation tokens ---------------------------------------------------

  test "tampered confirmation token is rejected gracefully" do
    get email_confirmation_url("garbage-token-value")
    assert_redirected_to login_path
  end

  test "expired confirmation token does not confirm" do
    user = User.create!(email: "expiry@example.com", password: "password123")
    token = user.generate_confirmation_token

    travel 16.minutes do
      get email_confirmation_url(token)
      assert_redirected_to login_path
    end
    assert_not user.reload.confirmed?
  end

  test "confirmation token for one user cannot confirm another" do
    token = @user.generate_confirmation_token
    unconfirmed = User.create!(email: "someone-else@example.com", password: "password123")

    get email_confirmation_url(token)
    assert_not unconfirmed.reload.confirmed?
  end

  # --- Rate limiting ----------------------------------------------------------

  test "login attempts are rate limited per IP" do
    10.times do
      post login_url, params: { user: { email: @user.email, password: "wrong" } }
      assert_response :unprocessable_entity
    end

    post login_url, params: { user: { email: @user.email, password: "wrong" } }
    assert_response :too_many_requests
  end

  test "rate limit blocks even correct credentials once tripped" do
    10.times { post login_url, params: { user: { email: @user.email, password: "wrong" } } }

    post login_url, params: { user: { email: @user.email, password: "password123" } }
    assert_response :too_many_requests
  end

  test "login page itself is not rate limited" do
    15.times { get login_url }
    assert_response :success
  end

  # --- Session lifecycle ------------------------------------------------------

  test "logout ends the session for subsequent requests" do
    sign_in_as @user
    get dashboard_url
    assert_response :success

    delete logout_url
    get dashboard_url
    assert_redirected_to login_path
  end
end
