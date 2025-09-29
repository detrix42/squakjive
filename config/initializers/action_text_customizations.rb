ActiveSupport.on_load(:action_text_attachables_remote_image) do
  attr_reader :href, :filename, :filesize, :content_type, :previewable

  def self.from_node(node)
    new(
      url: node["url"],
      width: node["width"],
      height: node["height"],
      href: node["href"],
      filename: node["filename"],
      filesize: node["filesize"],
      content_type: node["content-type"],
      previewable: node["previewable"]
    )
  end

  def initialize(url: nil, width: nil, height: nil, href: nil, filename: nil, filesize: nil, content_type: nil, previewable: nil)
    @url = url
    @width = width
    @height = height
    @href = href
    @filename = filename || "image"
    @filesize = filesize
    @content_type = content_type
    @previewable = previewable
  end
end
