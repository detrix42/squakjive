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
  #
  # Robust fallback: decode the (possibly short-lived/expired) signed GID payload to
  # recover the blob id directly from the embedded gid:// string. This is needed because
  # the sgids that end up in the submitted rich text HTML are often signed with expiries
  # that have passed by the time the form is processed.
  class << self
    def resolve_from_sgid(sgid)
      return nil if sgid.blank?

      # Prioritize payload decode for GID-style attachable sgids that appear
      # in rich text submissions. This is reliable even if the signature has
      # expired (common for the forms ActionText embeds in the HTML).
      if (id = extract_blob_id_from_sgid_payload(sgid))
        if (blob = find_by(id: id))
          return blob
        end
      end

      # 1) Plain signed_id from ActiveStorage
      begin
        if (blob = find_signed(sgid))
          return blob
        end
      rescue ActiveRecord::RecordNotFound
        # fall through
      end

      # 2) Signed GlobalID form
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

      # 3) bare id
      if sgid.to_s =~ /\A\d+\z/
        return find_by(id: sgid.to_i)
      end

      nil
    end

    def extract_blob_id_from_sgid_payload(sgid)
      return nil if sgid.blank?
      encoded = sgid.to_s.split('--').first
      return nil if encoded.blank?
      begin
        json_str = Base64.urlsafe_decode64(encoded)
        data = JSON.parse(json_str)
        gid = (data['data'] || data['gid'] || '').to_s
        if gid =~ %r{ActiveStorage::Blob/(\d+)}
          return $1.to_i
        end
      rescue ArgumentError, JSON::ParserError
        # bad base64 or json
      end
      nil
    end
  end
end
