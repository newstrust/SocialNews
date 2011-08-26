ActiveRecord::Schema.define(:version => 1) do
  create_table "foos", :force => true do |t|
  end
  
  create_table "people", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "person_contact_infos", :force => true do |t|
    t.integer "contact_id", :null => false
    t.string  "name",       :null => false
    t.string  "value",      :null => false
  end

  create_table "posts", :force => true do |t|
    t.string   "title"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "post_attributes", :force => true do |t|
    t.integer "post_id", :null => false
    t.string "name", :null => false
    t.string "value", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "preferences", :force => true do |t|
    t.integer "person_id", :null => false
    t.string  "key",       :null => false
    t.string  "value",     :null => false
  end
  
  create_table "documents", :force => true do |t|
    t.string "name", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  
  create_table "document_attributes", :force => true do |t|
    t.integer "document_id", :null => false
    t.string "name", :null => false
    t.string "value", :null => false
  end
  
  create_table "users", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end
