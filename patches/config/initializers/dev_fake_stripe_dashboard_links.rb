# frozen_string_literal: true

# Local-only: "View on Stripe" links (card, cardholder, personalization
# design) are built from the object's real-looking-but-fake Stripe ID
# (see dev_fakes.rb) and would otherwise send you to a real Stripe
# dashboard URL for an object that doesn't exist there. This neutralizes
# just those links (leaves it a plain "#" instead of removing the
# button, since the surrounding views don't expect this method to return
# nil) whenever the ID looks like one of our locally-generated fake IDs.
if Rails.env.development?
  module DevFakeStripeDashboardUrl
    def stripe_dashboard_url
      url = super
      return "#" if url&.match?(%r{/[a-z_]+_dev[0-9a-f]+\z})

      url
    end
  end

  Rails.application.config.after_initialize do
    StripeCard.prepend(DevFakeStripeDashboardUrl)
    StripeCardholder.prepend(DevFakeStripeDashboardUrl)
    StripeCard::PersonalizationDesign.prepend(DevFakeStripeDashboardUrl)
  end
end
