class RenameCustomerNameToName < ActiveRecord::Migration[7.1]
  def change
    rename_column :customers, :customer_name, :name
  end
end
