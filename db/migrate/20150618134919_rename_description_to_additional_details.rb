class RenameDescriptionToAdditionalDetails < ActiveRecord::Migration
  def change
    rename_column :petitions, :description, :additional_details
    rename_index :petitions, 'index_petitions_on_description', 'index_petitions_on_additional_details'
  end
end
