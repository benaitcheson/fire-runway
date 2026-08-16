# Up Bank sync configuration
# Create a personal access token in the Up app (or at https://api.up.com.au)
# and set:
#   UP_API_TOKEN=up:yeah:xxxxx
# When unset, the "Sync from Up" button on the budget page is replaced with a
# setup hint and the app otherwise works as before.
if Rails.env.development? && ENV["UP_API_TOKEN"].blank?
  Rails.logger.info "Up Bank sync disabled (UP_API_TOKEN not set)"
end
