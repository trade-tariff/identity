module Api
  class UsersController < Api::ApplicationController
    def show
      user = User.find(params[:id], @group)
      if user
        render json: { user: }, status: :ok
      else
        render json: { error: "User not found" }, status: :not_found
      end
    end

    def destroy
      User.destroy(params[:id], @group)
      render json: { message: "User deleted" }, status: :ok
    rescue User::DeletionError => e
      # Handled here rather than propagating, because the response is the whole
      # signal on a request path: the backend's deletion worker retries on a 5xx,
      # and a right-to-erasure request must never be answered with a success the
      # user did not get.
      Rails.logger.error(e.message)
      render json: { error: "Something went wrong" }, status: :internal_server_error
    end
  end
end
