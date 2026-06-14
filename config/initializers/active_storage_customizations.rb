ActiveSupport.on_load(:active_storage_blob) do
  class_eval do
    def to_attachable_partial_path
      "active_storage/blobs/custom_blob"
    end
  end

  # Resolve an sgid that may be either:
  # - a plain ActiveStorage signed_id (blob.signed_id from DirectUpload, used in many upload flows), or
  # - a signed GlobalID sgid (the format ActionText places in <action-text-attachment sgid="...">,
  #   which is a signed "gid://.../ActiveStorage::Blob/NN?..." with purpose "attachable").
  #
  # This prevents NoMethodError on nil when processing rich text bodies containing image (or other)
  # attachments, and ensures we can populate the embeds ActiveStorage::Attachment rows for ActionText resolution.
  class << self
    def resolve_from_sgid(sgid)
      return nil if sgid.blank?

      # 1) Plain signed_id from ActiveStorage (most upload JS paths set sgid or pass this to endpoints)
      begin
        if (blob = find_signed(sgid))
          return blob
        end
      rescue ActiveRecord::RecordNotFound
        # fall through to GlobalID form
      end

      # 2) Signed GlobalID form used by ActionText/Trix for attachables in rich text HTML
      begin
        located = GlobalID::Locator.locate_signed(sgid)
        return located if located.is_a?(ActiveStorage::Blob)
        if located && located.respond_to?(:blob)
          b = located.blob
          return b if b.is_a?(ActiveStorage::Blob)
        end
      rescue => e
        Rails.logger&.debug("ActiveStorage::Blob.resolve_from_sgid: locate_signed failed: #{e.class} #{e.message}")
      end

      # 3) Defensive: extract from a raw/unsigned gid url in the string, or a bare id
      s = sgid.to_s
      if s =~ %r{ActiveStorage::Blob/(\d+)}
        return find_by(id: $1.to_i)
      end
      if s =~ /\A\d+\z/
        return find_by(id: s.to_i)
      end

      nil
    end
  end
end
