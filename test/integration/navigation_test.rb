require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "current section is marked with aria-current" do
    get user_assets_url
    assert_select "nav a[aria-current=page]", text: "Assets"
    assert_select "a[aria-current=page]", count: 1
  end

  test "nested pages still mark their section" do
    get new_user_asset_url
    assert_select "nav a[aria-current=page]", text: "Assets"
  end

  test "sign out is a real button, not a link" do
    get dashboard_url
    assert_select "nav form[action=?]", logout_path do
      assert_select "button", text: "Sign out"
    end
  end

  test "skip link and main landmark exist" do
    get dashboard_url
    assert_select "a[href='#main-content']"
    assert_select "main#main-content"
  end

  test "brand says FireRunway" do
    get dashboard_url
    assert_select "nav a", text: "FireRunway"
  end
end
