module RedmineSlack
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          safe_attributes "slack_hook_url", "slack_channel_name", "slack_notify"
        end
      end
    end
  end
end
