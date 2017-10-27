class CreateParkingEntrances < ActiveRecord::Migration[4.2]
  def change
    create_table :parking_entrances do |t|
      t.integer :parking_entrance_id
      t.st_point :geom, geographic: true

      t.timestamps null: false
    end
  end
end
