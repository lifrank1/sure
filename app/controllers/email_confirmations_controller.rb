class EmailConfirmationsController < ApplicationController
  skip_before_action :set_request_details, only: [ :new, :signup ]
  skip_authentication only: [ :new, :signup ]

  def new
    # Returns nil if the token is invalid OR expired
    @user = User.find_by_token_for(:email_confirmation, params[:token])

    if @user&.unconfirmed_email && @user&.update(
      email: @user.unconfirmed_email,
      unconfirmed_email: nil
    )
      redirect_to new_session_path, notice: t(".success_login")
    else
      redirect_to root_path, alert: t(".invalid_token")
    end
  end

  # Signup verification: confirms the CURRENT address. Works logged in or out.
  def signup
    user = User.find_by_token_for(:signup_confirmation, params[:token])

    if user
      user.confirm_email!
      if Current.user
        redirect_to root_path, notice: t(".success")
      else
        redirect_to new_session_path, notice: t(".success_login")
      end
    else
      redirect_to root_path, alert: t(".invalid_token")
    end
  end

  def resend
    if Current.user.needs_email_confirmation?
      EmailConfirmationMailer.with(user: Current.user).signup_confirmation_email.deliver_later
    end

    redirect_back fallback_location: root_path, notice: t(".sent", email: Current.user.email)
  end
end
