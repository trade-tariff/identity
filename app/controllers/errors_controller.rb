class ErrorsController < ApplicationController
  def not_found
    message = "This page does not exist.".html_safe

    respond_to do |format|
      format.html { render "error", status: :not_found, locals: { header: "Not found", message: } }
      format.all { render status: :not_found, plain: "Not found" }
    end
  end

  def bad_request
    message = "The request you made is not valid.<br>
               Please contact support for assistance or try a different request.".html_safe

    respond_to do |format|
      format.html { render "error", status: :bad_request, locals: { header: "Bad request", message: } }
      format.all { render status: :bad_request, plain: "Bad request" }
    end
  end

  def internal_server_error
    message = "We are experiencing technical difficulties".html_safe

    respond_to do |format|
      format.html { render "error", status: :internal_server_error, locals: { header: "Internal server error", message: } }
      format.all { render status: :internal_server_error, plain: "Internal server error" }
    end
  end
end
