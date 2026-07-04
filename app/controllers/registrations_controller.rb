class RegistrationsController < ApplicationController
  skip_authentication

  layout "auth"

  before_action :ensure_signup_open, if: :self_hosted?
  before_action :set_user, only: :create
  before_action :set_invitation
  before_action :validate_password_requirements, only: :create

  def new
    @user = User.new(email: @invitation&.email)
  end

  def create
    if @invitation
      @user.family = @invitation.family
      @user.role = @invitation.role
      @user.email = @invitation.email
    elsif (default_family_id = Setting.invite_only_default_family_id).present? &&
          Setting.onboarding_state == "invite_only" &&
          (default_family = Family.find_by(id: default_family_id))
      @user.family = default_family
      @user.role = :member
    else
      family = Family.new
      @user.family = family
      @user.role = User.role_for_new_family_creator
    end

    # Skip the multi-step onboarding flow (name/preferences/goals survey):
    # family defaults (USD, en) cover everything it collects, and users can
    # change name/theme/locale in Settings at any time.
    @user.onboarded_at = Time.current

    if signup_with_invite_claim!
      create_default_auto_categorize_rule
      redirect_to root_path, notice: t(".success")
    elsif @invite_code_invalid
      redirect_to new_registration_path, alert: t("registrations.create.invalid_invite_code")
    else
      render :new, status: :unprocessable_entity, alert: t(".failure")
    end
  end

  private

    # Every family gets an active AI auto-categorize rule so cashflow is
    # accurate out of the box. Family syncs apply active rules automatically
    # (Family::Syncer), and the executor only touches uncategorized
    # transactions. Failures must never block a signup.
    def create_default_auto_categorize_rule
      family = @user.family
      return if family.nil? || family.rules.exists?

      rule = family.rules.new(
        name: "Auto-categorize transactions",
        resource_type: "transaction",
        active: true
      )
      rule.actions.build(action_type: "auto_categorize")
      rule.save!
    rescue => e
      Rails.logger.error("Default auto-categorize rule creation failed for family #{family&.id}: #{e.message}")
    end

    def set_invitation
      token = params[:invitation]
      token ||= params[:user][:invitation] if params[:user].present?
      @invitation = Invitation.pending.find_by(token: token)
    end

    def set_user
      @user = User.new user_params.except(:invite_code, :invitation)
    end

    def user_params(specific_param = nil)
      params = self.params.require(:user).permit(:name, :email, :password, :password_confirmation, :invite_code, :invitation)
      specific_param ? params[specific_param] : params
    end

    # Keep save+claim atomic so failed signups never burn valid invite codes.
    def signup_with_invite_claim!
      invite_code = user_params[:invite_code]
      @invite_code_invalid = invite_code_required? && invite_code.blank?
      return false if @invite_code_invalid

      success = false

      ActiveRecord::Base.transaction do
        unless @user.save
          raise ActiveRecord::Rollback
        end

        if invite_code_required? && !InviteCode.claim!(invite_code)
          @invite_code_invalid = true
          raise ActiveRecord::Rollback
        end

        @invitation&.update!(accepted_at: Time.current)
        @session = create_session_for(@user)
        success = true
      end

      success
    end

    def validate_password_requirements
      password = user_params[:password]
      return if password.blank? # Let Rails built-in validations handle blank passwords

      if password.length < 8
        @user.errors.add(:password, "must be at least 8 characters")
      end

      unless password.match?(/[A-Z]/) && password.match?(/[a-z]/)
        @user.errors.add(:password, "must include both uppercase and lowercase letters")
      end

      unless password.match?(/\d/)
        @user.errors.add(:password, "must include at least one number")
      end

      unless password.match?(/[!@#$%^&*(),.?":{}|<>]/)
        @user.errors.add(:password, "must include at least one special character")
      end

      if @user.errors.present?
        render :new, status: :unprocessable_entity
      end
    end

    def ensure_signup_open
      return unless Setting.onboarding_state == "closed"

      redirect_to new_session_path, alert: t("registrations.closed")
    end
end
