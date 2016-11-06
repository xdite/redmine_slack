# encoding: utf-8
require "httpclient"
class NotificationHook < Redmine::Hook::Listener
  def controller_issues_new_after_save(context = {})
    issue   = context[:issue]
    project = issue.project
    return true unless slack_configured?(project)

    author  = CGI.escapeHTML(User.current.name)
    tracker = CGI.escapeHTML(issue.tracker.name.downcase)
    subject = CGI.escapeHTML(issue.subject)
    url     = get_url(issue)

    assigned_message = issue.assigned_to.nil? ? "NULL" : issue.assigned_to.name.to_s

    text =   "#{author} 建立 #{tracker} <#{url}|#{issue.id}> : #{subject}"
    text +=  "狀態:「#{issue.status.name}」. 分派給:「#{assigned_message}」. 意見:「#{truncate(issue.description)}」"

    data          = {}
    data[:text]   = text
    data[:slack_hook_url] = slack_hook_url(project)
    data[:room]   = slack_channel_name(project)
    data[:notify] = slack_notify(project)

    send_message(data)
  end

  def controller_issues_edit_before_save(context = {})
    issue   = context[:issue]
    project = issue.project
    journal = context[:journal]
    editor = journal.user
    tracker = CGI.escapeHTML(issue.tracker.name.downcase)
    assigned_message = issue_assigned_changed?(issue)
    status_message = issue_status_changed?(issue)
    url     = get_url(issue)
    subject = CGI.escapeHTML(issue.subject)

    text = ""
    text += "#{editor.name} 編輯 #{tracker} <#{url}|#{issue.id}> : #{subject}."
    text += "狀態:「#{status_message}」. 分派給:「#{assigned_message}」. 意見:「#{truncate(journal.notes)}」"

    data          = {}
    data[:text]   = text
    data[:slack_hook_url] = slack_hook_url(project)
    data[:room]   = slack_channel_name(project)
    data[:notify] = slack_notify(project)

    send_message(data)
  end

  def controller_wiki_edit_after_save(context = {})
    page    = context[:page]
    project = page.wiki.project
    return true unless slack_configured?(project)

    author       = CGI.escapeHTML(User.current.name)
    wiki         = CGI.escapeHTML(page.pretty_title)
    project_name = CGI.escapeHTML(project.name)
    url          = get_url(page)
    text         = "#{author} edited #{project_name} wiki page <#{url}|#{wiki}>"

    text = ""
    text += "#{author} edited the  <#{url}|#{wiki}> on #{project.name}."

    data          = {}
    data[:text]   = text
    data[:slack_hook_url] = slack_hook_url(project)
    data[:room]   = slack_channel_name(project)
    data[:notify] = slack_notify(project)

    send_message(data)
  end

  private

  def slack_configured?(project)
    if !project.slack_hook_url.empty? && !project.slack_channel_name.empty?
      return true
    elsif Setting.plugin_redmine_slack[:projects] &&
          Setting.plugin_redmine_slack[:projects].include?(project.id.to_s) &&
          Setting.plugin_redmine_slack[:slack_url] &&
          Setting.plugin_redmine_slack[:channel_name]
      return true
    else
      Rails.logger.info "Not sending Slack message - missing config"
    end
    false
 end

  def slack_hook_url(project)
    return project.slack_hook_url unless project.slack_hook_url.empty?
    Setting.plugin_redmine_slack[:slack_url]
  end

  def slack_channel_name(project)
    return project.slack_channel_name unless project.slack_channel_name.empty?
    Setting.plugin_redmine_slack[:channel_name]
  end

  def slack_notify(project)
    return project.slack_notify if !project.slack_hook_url.empty? && !project.slack_channel_name.empty?
    Setting.plugin_redmine_slack[:notify]
  end

  def get_url(object)
    case object
    when Issue    then "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{object.id}"
    when WikiPage then "#{Setting[:protocol]}://#{Setting[:host_name]}/projects/#{object.wiki.project.identifier}/wiki/#{object.title}"
    else
      Rails.logger.info "Asked redmine_slack for the url of an unsupported object #{object.inspect}"
    end
  end

  def send_message(data)
    username = "redmine-bot"
    channel = data[:room]
    url = data[:slack_hook_url]
    icon = "X"
    params = {
      text: data[:text],
      link_names: 1
    }

    Rails.logger.info data

    params[:username] = username if username
    params[:channel] = channel if channel

    if icon && !icon.empty?
      if icon.start_with? ":"
        params[:icon_emoji] = icon
      else
        params[:icon_url] = icon
      end
    end

    client = HTTPClient.new

    client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

    client.post url, payload: params.to_json
  end

  def truncate(text, length = 20, end_string = "…")
    return unless text
    words = text.split
    words[0..(length - 1)].join(" ") + (words.length > length ? end_string : "")
  end

  def issue_status_changed?(issue)
    if issue.status_id_changed?
      old_status = IssueStatus.find(issue.status_id_was)
      "從 #{old_status.name} 變更為 #{issue.status.name}"
    else
      issue.status.name.to_s
    end
  end

  def issue_assigned_changed?(issue)
    if issue.assigned_to_id_changed?
      old_assigned_to =
        begin
          User.find(issue.assigned_to_id_was)
        rescue
          nil
        end
      old_assigned = old_assigned_to.nil? ? "無" : "#{old_assigned_to.lastname} #{old_assigned_to.firstname}"
      new_assigned = issue.assigned_to.nil? ? "無" : "#{issue.assigned_to.lastname} #{issue.assigned_to.firstname}"
      "從 #{old_assigned} 變更為 #{new_assigned}"
    else
      issue.assigned_to.nil? ? "無" : "#{issue.assigned_to.lastname} #{issue.assigned_to.firstname}"
    end
  end
end
