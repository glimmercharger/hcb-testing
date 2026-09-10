# frozen_string_literal: true

# Local-only: removes the login gate entirely. Every request is
# auto-authenticated as the seeded dev admin (admin@bank.engineering) --
# there's no login page, no magic-link code, nothing to click through.
#
# Only active in development; production/staging/test are untouched.
if Rails.env.development?
  module DevAutoLogin
    def find_current_session
      existing = super
      return existing if existing

      user = User.find_by(email: "admin@bank.engineering") || User.first
      return nil unless user

      create_session(user:, verified: true)
    end
  end

  Rails.application.config.after_initialize do
    ApplicationController.prepend(DevAutoLogin)
  end
end
