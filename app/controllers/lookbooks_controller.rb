# Lookbook is a development-only gem; in environments without it this class
# must still define (Zeitwerk expects the constant), so it degrades to an
# inert base controller. It is only routed/referenced when Lookbook is loaded
# (config/application.rb, config/routes.rb).
class LookbooksController < (defined?(Lookbook) ? Lookbook::PreviewController : ActionController::Base)
  layout "lookbooks" if defined?(Lookbook)
end
