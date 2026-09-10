# frozen_string_literal: true

# Local-only: removes the login gate entirely. Every request is
# auto-authenticated as the seeded dev admin (admin@bank.engineering) --
# there's no login page, no magic-link code, nothing to click through.
#
# Also skips the "verified phone number" requirement for issuing a card --
# there's no Twilio account locally to actually send/verify an SMS code
# against, so this would otherwise permanently block card issuing.
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

  module DevSkipPhoneVerification
    def phone_number_verified_or_bypassed?
      true
    end
  end

  Rails.application.config.after_initialize do
    ApplicationController.prepend(DevAutoLogin)
    User.prepend(DevSkipPhoneVerification)
  end
end
