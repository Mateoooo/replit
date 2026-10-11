class AddHostPortToRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :runs, :host_port, :integer
  end
end
