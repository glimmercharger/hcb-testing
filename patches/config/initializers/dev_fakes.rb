# frozen_string_literal: true

# Local-only development fakes.
#
# This app is normally wired up to Stripe (card issuing) and Column (banking
# rails) sandbox accounts. For a fully local demo with no third-party
# credentials, this file short-circuits the handful of Stripe Issuing API
# calls HCB makes so that requesting/activating a card "succeeds" instantly
# with realistic-looking fake data, instead of failing with an
# authentication error against the real Stripe API.
#
# None of this touches money movement (Column/ACH/wires) -- those flows are
# left alone and simply won't be reachable without real credentials. Fake
# organization balances are seeded directly at the ledger level instead (see
# db/seeds.rb / bin/seed_fake_org), which requires no third-party calls.
if Rails.env.development?
  module DevFakeStripeIssuing
    def self.fake_id(prefix)
      "#{prefix}_dev#{SecureRandom.hex(12)}"
    end

    module Card
      def create(params = {}, opts = {})
        now = Time.now.utc
        physical = params[:type].to_s == "physical"

        values = {
          id: DevFakeStripeIssuing.fake_id("ic"),
          object: "issuing.card",
          brand: "Visa",
          cardholder: params[:cardholder],
          created: now.to_i,
          currency: params[:currency] || "usd",
          exp_month: (now + 4.years).month,
          exp_year: (now + 4.years).year,
          last4: format("%04d", rand(10_000)),
          number: "4242424242424242",
          cvc: format("%03d", rand(1_000)),
          status: params[:status] || (physical ? "inactive" : "active"),
          type: params[:type] || "virtual",
          personalization_design: params[:personalization_design],
          spending_controls: params[:spending_controls],
          metadata: params[:metadata] || {}
        }

        if physical
          values[:shipping] = (params[:shipping] || {}).merge(
            status: "delivered",
            carrier: "USPS",
            tracking_number: "9400#{rand(10**16..(10**17 - 1))}",
            tracking_url: nil,
            eta: (now + 2.weeks).to_i
          )
        end

        ::Stripe::Issuing::Card.construct_from(values)
      end

      def retrieve(id = nil, opts = {})
        id = id[:id] if id.is_a?(Hash)

        ::Stripe::Issuing::Card.construct_from(
          id: id,
          object: "issuing.card",
          brand: "Visa",
          created: 1.month.ago.to_i,
          currency: "usd",
          exp_month: (Time.now.utc + 4.years).month,
          exp_year: (Time.now.utc + 4.years).year,
          last4: "4242",
          number: "4242424242424242",
          cvc: "123",
          status: "active",
          type: "virtual",
          shipping: nil,
          spending_controls: { spending_limits: [] },
          replacement_for: nil
        )
      end

      def update(id, params = {}, opts = {})
        ::Stripe::Issuing::Card.construct_from(
          id:,
          object: "issuing.card",
          brand: "Visa",
          created: 1.month.ago.to_i,
          currency: "usd",
          exp_month: (Time.now.utc + 4.years).month,
          exp_year: (Time.now.utc + 4.years).year,
          last4: "4242",
          number: "4242424242424242",
          cvc: "123",
          status: params[:status] || "active",
          type: "virtual"
        )
      end
    end

    module Cardholder
      def create(params = {}, opts = {})
        ::Stripe::Issuing::Cardholder.construct_from(
          id: DevFakeStripeIssuing.fake_id("ich"),
          object: "issuing.cardholder",
          name: params[:name],
          email: params[:email],
          phone_number: params[:phone_number],
          status: "active",
          type: params[:type] || "individual",
          billing: params[:billing],
          created: Time.now.utc.to_i
        )
      end

      def retrieve(id = nil, opts = {})
        id = id[:id] if id.is_a?(Hash)

        ::Stripe::Issuing::Cardholder.construct_from(
          id: id,
          object: "issuing.cardholder",
          status: "active",
          type: "individual",
          requirements: {},
          created: Time.now.utc.to_i
        )
      end

      def update(id, params = {}, opts = {})
        ::Stripe::Issuing::Cardholder.construct_from(
          id:,
          object: "issuing.cardholder",
          status: "active",
          type: "individual",
          requirements: {},
          created: Time.now.utc.to_i
        )
      end
    end

    module PersonalizationDesign
      def create(params = {}, opts = {})
        ::Stripe::Issuing::PersonalizationDesign.construct_from(
          id: DevFakeStripeIssuing.fake_id("pd"),
          object: "issuing.personalization_design",
          status: "active",
          lookup_key: params[:lookup_key],
          created: Time.now.utc.to_i
        )
      end
    end

    module Transaction
      def retrieve(id = nil, opts = {})
        id = id[:id] if id.is_a?(Hash)

        ::Stripe::Issuing::Transaction.construct_from(
          id: id,
          object: "issuing.transaction",
          amount: 0,
          created: Time.now.utc.to_i
        )
      end
    end

    module File
      def create(params = {}, opts = {})
        ::Stripe::File.construct_from(
          id: DevFakeStripeIssuing.fake_id("file"),
          object: "file",
          purpose: params[:purpose],
          created: Time.now.utc.to_i
        )
      end
    end
  end

  module DevFakeStripePhysicalBundleIds
    def physical_bundle_ids
      { white: "icb_dev_white", black: "icb_dev_black" }
    end
  end

  Rails.application.config.after_initialize do
    StripeService.singleton_class.prepend(DevFakeStripePhysicalBundleIds)
    Stripe::Issuing::Card.singleton_class.prepend(DevFakeStripeIssuing::Card)
    Stripe::Issuing::Cardholder.singleton_class.prepend(DevFakeStripeIssuing::Cardholder)
    Stripe::Issuing::PersonalizationDesign.singleton_class.prepend(DevFakeStripeIssuing::PersonalizationDesign)
    Stripe::Issuing::Transaction.singleton_class.prepend(DevFakeStripeIssuing::Transaction)
    Stripe::File.singleton_class.prepend(DevFakeStripeIssuing::File)
  end
end
