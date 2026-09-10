# frozen_string_literal: true

# Local-only: HCB pins the host used for absolute URLs (_url helpers, as
# opposed to _path helpers) to TEST_URL_HOST, which normally matches
# wherever you're actually browsing from (localhost:3000 for a plain local
# setup). When this app is reached through something else instead (a
# tunnel, a forwarded port), any link built with an absolute _url helper
# -- like a fiscal sponsorship application's "view" link -- still points
# at literal "localhost:3000", which isn't reachable from outside this
# machine.
#
# This makes controllers use the *current request's* host for any URL
# built during an actual request, so those links match whatever address
# you used to reach the app. Background jobs and mailers have no request
# to read, so they keep using TEST_URL_HOST as a fallback, same as before.
if Rails.env.development?
  module DevDynamicHost
    def default_url_options
      super.merge(host: request.host, port: request.port)
    end
  end

  Rails.application.config.after_initialize do
    ApplicationController.prepend(DevDynamicHost)
  end
end
