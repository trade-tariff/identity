namespace :cleanup do
  desc "Remove Cognito users with unverified email addresses older than one day"
  task remove_unverified_users: :environment do
    RemoveUnverifiedUsers.call
  rescue User::DeletionError => e
    # EventBridge does not alarm on a failed ECS task, so the only signal that
    # reaches CloudWatch is what this container logs before it exits non-zero.
    # Log the reason explicitly, then re-raise so rake exits 1 and the stopped
    # task carries a non-zero exit code rather than looking like a clean run.
    Rails.logger.error("cleanup:remove_unverified_users aborted: #{e.message}")
    raise
  end
end
