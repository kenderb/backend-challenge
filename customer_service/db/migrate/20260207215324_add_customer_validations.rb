class AddCustomerValidations < ActiveRecord::Migration[7.1]
  def change
    change_column_null :customers, :name, false
    change_column_null :customers, :address, false
    add_index :customers, :name, unique: true
  end
end
