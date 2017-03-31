roles_with_nil_content_ids = Role.where(content_id: nil)

roles_with_nil_content_ids.each do |role|
  role.content_id = SecureRandom.uuid
end

roles_with_nil_content_ids.each(&:save)
