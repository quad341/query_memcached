class User < ActiveRecord::Base
   class << self # class methods
     def _load(input)
        vals = input.split(',')
        vals.map! { |e| CGI::unescape(e) }
        u = User.new
        u.username = vals[0]
        u.first_name = vals[1]
        u.middle_name = vals[2]
        u.last_name = vals[3]
        u.full_name = vals[4]
        u.title = vals[5]
        u.email = vals[6]
        u.im_id = vals[7]
        u.employee_id = vals[8].to_i
        u.manager_username = vals[9]
        u.manager_id = vals[10].to_i
        u.phone_number = vals[11]
        u.acting_manager_id = vals[12].to_i
        u.picture_exists = vals[13] == "true"
        u.enabled = vals[14] == "true"
        u.updated_at = Time.parse(vals[15])
        u.updated_by = vals[16].to_i
        u.created_at = Time.parse(vals[17])
        u.created_by = vals[18].to_i
        u.realm_id = vals[19].to_i
        u.manager_valid = vals[20] == "true"
        u.work_country = vals[21]
        u.write_attribute(:materialized_path,  vals[22])
        u.id = vals[23].to_i
        u
     end
  end

  def _dump(depth)
     [ username, first_name, middle_name, last_name, full_name, title, email,
        im_id, employee_id.to_s, manager_username, manager_id.to_s,
        phone_number, acting_manager_id.to_s, picture_exists.to_s,
        enabled.to_s, updated_at.to_s, updated_by.to_s, created_at.to_s,
        created_by.to_s, realm_id.to_s, manager_valid.to_s, work_country,
        materialized_path, id.to_s ].map { |e| CGI::escape(e) }.join(',')
  end
end
