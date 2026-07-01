Rails.application.configure do
  config.x.product_name = ENV.fetch("PRODUCT_NAME", "Frank Finance")
  config.x.brand_name = ENV.fetch("BRAND_NAME", "")
end
