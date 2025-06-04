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
  end
end
