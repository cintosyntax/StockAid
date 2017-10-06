class ConvertVersionsObjectToJson < ActiveRecord::Migration
  def change
    rename_column :versions, :object, :old_object
    add_column :versions, :object, :jsonb

    PaperTrail::Version.where.not(old_object: nil).find_each do |version|
      version.update_columns old_object: nil, object: YAML.load(version.old_object)
    end

    remove_column :versions, :old_object
  end
end