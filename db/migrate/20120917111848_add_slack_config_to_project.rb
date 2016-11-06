class AddSlackConfigToProject < ActiveRecord::Migration
  def change
    add_column :projects, :slack_hook_url, :string, default: '', null: false
    add_column :projects, :slack_channel_name, :string, default: '', null: false
    add_column :projects, :slack_notify, :boolean, default: false, null: false
  end
end
