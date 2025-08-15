# lifted from bc3 app/models/launchpad.rb
module Launchpad
  extend self

  delegate :url, to: "SignalId.launchpad"

  def login_url(product: false, account: nil, **params)
    url product_account_path("/signin", product: product, account: account), params
  end

  def logout_url
    url "/signout"
  end

  def authentication_url(**params)
    url "/authenticate", params.merge(product: :fizzy)
  end

  def product_account_path(path = nil, product: false, account: nil)
    product_path = "/fizzy" if product || account
    account_path = "/#{account.signal_account.id}" if account
    [ product_path, account_path, path ].compact.join
  end
end
