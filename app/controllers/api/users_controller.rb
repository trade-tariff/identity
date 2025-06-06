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
      if User.destroy(params[:id], @group)
        render json: { message: "User deleted" }, status: :ok
      else
        render json: { error: "Something went wrong" }, status: :internal_server_error
      end
    end
  end
end
