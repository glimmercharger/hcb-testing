# frozen_string_literal: true

# Creates a demo organization ("event") seeded with a $25,000,000 balance.
# Run with: bin/rails runner bin/seed_rich_org.rb
user = User.find_by!(email: "admin@bank.engineering")

event = Event.find_by(slug: "megafund") || Event.create!(
  name: "Hack Club Megafund",
  slug: "megafund",
  can_front_balance: true,
  point_of_contact: user,
  is_public: true,
  created_at: 1.day.ago
)

# Fee-exempt, like the other demo/internal orgs in db/seeds.rb, so the full
# deposited amount is reflected in the available balance.
event.plan.update!(type: "Event::Plan::HackClubAffiliate") unless event.plan.is_a?(Event::Plan::HackClubAffiliate)

unless OrganizerPosition.exists?(event:, user:) || OrganizerPositionInvite.exists?(event:, user:)
  OrganizerPositionInvite.create!(
    event:,
    user:,
    sender: user,
  )
end

# NOTE: `amount:` here is dollars (RawCsvTransactionService uses
# `.to_money`, not raw cents). amount_cents columns are 4-byte ints (max
# ~$21.47M), so $25M is split into a few deposits that each stay under
# that limit.
[10_000_000, 10_000_000, 5_000_000].each do |dollars|
  ::RawCsvTransactionService::Create.new(
    unique_bank_identifier: "FSMAIN",
    date: 1.day.ago.iso8601(3),
    memo: "\u{1F4B0} Megafund Seed Deposit",
    amount: dollars
  ).run

  ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
  ::TransactionEngine::CanonicalTransactionService::Import::All.new.run

  CanonicalEventMapping.create!(
    canonical_transaction_id: CanonicalTransaction.last.id,
    event_id: event.id,
    user_id: user.id
  )
end

puts "Event ##{event.id} (#{event.slug}) balance: #{event.balance_available_v2_cents / 100.0}"
