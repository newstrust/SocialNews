class AddAccessTokenToFbcSettings < ActiveRecord::Migration
  def self.up
    add_column :facebook_connect_settings, :access_token, :string
  end

  def self.down
    remove_column :facebook_connect_settings, :access_token
  end
end
