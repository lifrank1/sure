class InvitationsController < ApplicationController
  skip_authentication only: :accept
  def new
    @invitation = Invitation.new
  end

  def create
    unless Current.user.admin?
      flash[:alert] = t(".failure")
      redirect_to settings_profile_path
      return
    end

    @invitation = Current.family.invitations.build(invitation_params)
    @invitation.inviter = Current.user

    if @invitation.save
      # Never mutate an existing user's family/role as a side effect of the
      # inviter's action. Both new and existing users accept the invitation
      # from their own authenticated session (see accept_pending_invitation_for),
      # which is where the family/role change is actually applied. Response is
      # identical whether or not the email matched an existing user, so the
      # endpoint can't be used to enumerate registered accounts. The copyable
      # invite link surfaces on the settings page for the admin to share.
      InvitationMailer.invite_email(@invitation).deliver_later unless self_hosted?
      flash[:notice] = t(".success")
    else
      flash[:alert] = t(".failure")
    end

    redirect_to settings_profile_path
  end

  def accept
    @invitation = Invitation.find_by!(token: params[:id])

    if @invitation.pending?
      render :accept_choice, layout: "auth"
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def destroy
    unless Current.user.admin?
      flash[:alert] = t("invitations.destroy.not_authorized")
      redirect_to settings_profile_path
      return
    end

    @invitation = Current.family.invitations.find(params[:id])

    if @invitation.destroy
      flash[:notice] = t("invitations.destroy.success")
    else
      flash[:alert] = t("invitations.destroy.failure")
    end

    redirect_to settings_profile_path
  end

  private

    def invitation_params
      params.require(:invitation).permit(:email, :role)
    end
end
