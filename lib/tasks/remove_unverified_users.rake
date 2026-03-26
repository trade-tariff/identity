namespace :cleanup do
  desc "Remove Cognito users with unverified email addresses older than one day"
  task remove_unverified_users: :environment do
    RemoveUnverifiedUsers.call
  end
end
