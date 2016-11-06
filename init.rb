Redmine::Plugin.register :redmine_slack do
  name "Slack"
  author "xdite"
  description "Sends notifications to a Slack Channel"
  version "2.0.0"
  url "https://github.com/xdite/redmine_slack"
  author_url "https://github.com/xdite/redmine_slack"

  Rails.configuration.to_prepare do
    require_dependency "slack_hooks"
    require_dependency "slack_view_hooks"
    require_dependency "project_patch"
    Project.send(:include, RedmineSlack::Patches::ProjectPatch)
  end

  settings partial: "settings/redmine_slack",
           default: {
             room_id: "",
             auth_token: ""
           }
end
