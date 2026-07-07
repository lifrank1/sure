# Be sure to restart your server when you modify this file.
#
# Content Security Policy. Defense-in-depth against XSS, clickjacking, and
# unexpected outbound connections. See:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Notes on this app's policy:
# - script-src is nonce-based: every inline <script> (dark/privacy mode checks,
#   PostHog, doorkeeper/mobile-SSO auto-submit, importmap tags) carries
#   content_security_policy_nonce. No 'unsafe-inline' for scripts.
# - style-src allows 'unsafe-inline' because the UI uses inline style="" width
#   attributes (progress bars, chart fills). Style injection is far lower risk
#   than script injection.
# - img-src allows https + data: so bank/merchant/security logos (Brandfetch
#   CDN, provider logos) and inline data-URI images render.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https
    policy.frame_src   :self, :https
    policy.base_uri    :self
    policy.form_action :self, :https
    policy.frame_ancestors :self
  end

  # Nonce for inline <script> tags (and importmap). Keyed off the session id so
  # fragment-cached pages stay cacheable (a per-request random nonce would bust
  # the cache on every request).
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
