ActiveSupport.on_load(:active_storage_blob) do
  class_eval do
    def to_attachable_partial_path
      "active_storage/blobs/custom_blob"
    end
  end
end
