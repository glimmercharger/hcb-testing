# frozen_string_literal: true

# Local-only: HCB's admin panel links out to several real, internal Hack
# Club Airtable bases (application review queue, stickers, disputes,
# feedback, etc.) -- both as dashboard "task" tiles and as quick-jump
# entries in the Cmd+K command bar. This keeps those tiles/entries visible
# (so the admin panel still looks/feels the same) but sends them nowhere
# instead of out to a real internal tool.
if Rails.env.development?
  module DevFakeAirtableLinks
    def link_to_airtable_task(_task_name)
      "#"
    end
  end

  module DevFakeAirtableTaskSize
    def airtable_task_size(_task_name)
      0
    end
  end

  module DevFakeAirtableApplicationUrl
    def airtable_url
      nil
    end
  end

  Rails.application.config.after_initialize do
    StaticPagesHelper.prepend(DevFakeAirtableLinks)
    AdminController.prepend(DevFakeAirtableTaskSize)
    Event::Application.prepend(DevFakeAirtableApplicationUrl)
  end
end
