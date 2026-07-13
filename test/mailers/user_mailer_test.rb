require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "confirmation" do
    user = users(:one)
    mail = UserMailer.confirmation(user, user.generate_confirmation_token)
    assert_equal "Confirm your account", mail.subject
    assert_equal [user.email], mail.to
  end
end
