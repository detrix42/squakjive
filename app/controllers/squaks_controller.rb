class SquaksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_squak, only: [ :destroy]

  def index
    @circle = getCircle
    @squaks = Squak.for_circle(@circle).reorder(id: :desc).limit(20)
  end

  def create
    squak_attrs = params.expect(squak: [:body, :circle_id, preview_urls: {}])
    preview_urls = (squak_attrs.delete(:preview_urls) || {}).to_h
    @squak = current_user.squaks.new(squak_attrs)

    Rails.logger.debug "Squak params: #{squak_attrs.inspect}"
    Rails.logger.debug "Squak body before save: #{@squak.body&.body&.to_s.truncate(200)}"
    Rails.logger.debug "Embeds before save: #{@squak.body&.embeds.inspect}"

    # Process any embedded sgids from the rich text body (from the Trix editor HTML).
    # - Merge client-provided preview_url (from the separate preview_urls form field populated
    #   by attachments_controller.js) into blob metadata so our custom PDF rendering partials
    #   can emit the thumbnail <img> using the pre-generated representation URL.
    # - Force analyze (so previewable? is true and the /preview endpoint would have worked).
    #
    # We collect the blobs here, then AFTER the save (when the RichText record exists) we
    # explicitly do rich_text_body.embeds.attach(blob). This guarantees the
    # active_storage_attachments row (record_type: 'ActionText::RichText', name: 'embeds')
    # that ActionText's attachment resolver needs at render time.
    #
    # In this app the normal auto-creation of those embeds attachments from sgids present
    # in the saved body was not firing for PDF attachments (even after ActionText normalizes
    # the trix figure into <action-text-attachment sgid=...>). The previous manual build
    # was also broken (wrong `record:`). Explicit attach after save fixes the link without
    # the side-effects we saw.
    processed_blobs = []

    # Process sgids defensively. A bad/malformed attachment sgid (or resolver issue) must never
    # 500 the entire Squak create. We log and continue so the text (if any) can still save.
    begin
      if @squak.body&.body&.to_s.match(/sgid="([^"]+)"/)
        sgids = @squak.body.body.to_s.scan(/sgid="([^"]+)"/).flatten.uniq
        Rails.logger.debug "Found SGIDs in body: #{sgids}"

        sgids.each do |sgid|
          begin
            blob = nil
            begin
              blob = ActiveStorage::Blob.resolve_from_sgid(sgid) if ActiveStorage::Blob.respond_to?(:resolve_from_sgid)
            rescue
              # fall through to local resolver
            end
            blob ||= safe_resolve_blob_from_sgid(sgid)

            if blob.nil?
              Rails.logger.error "Blob not found for sgid: #{sgid}"
              next
            end
            Rails.logger.debug "Processing blob #{blob.id}: #{blob.filename}"

            if preview_urls.key?(sgid)
              preview_url = preview_urls[sgid]
              blob.update!(metadata: blob.metadata.merge(preview_url: preview_url))
              Rails.logger.debug "Updated blob #{blob.id} metadata with preview_url: #{preview_url}"
            end

            # Ensure blob is analyzed synchronously
            blob.analyze unless blob.analyzed?

            processed_blobs << blob
          rescue => e
            Rails.logger.error "Error processing sgid #{sgid}: #{e.class} #{e.message}"
          end
        end
      end
    rescue => e
      Rails.logger.error "Non-fatal SGID processing error in create (proceeding with save): #{e.class} #{e.message}"
    end

    # Inline custom HTML for PDF and video attachments.
    # We replace the <action-text-attachment sgid=...> (and its preceding text node if present)
    # with the preview figure block FIRST, followed by the squak text in its own <p>.
    # This ensures:
    #   - Preview image (thumbnail for video)
    #   - Centered text link to the file directly below the preview
    #   - The original squak text in its own paragraph below the whole attachment block
    # It completely bypasses ActionText's sgid resolver / missing attachable.
    if @squak.body&.body&.to_s.present?
      html = @squak.body.body.to_s
      processed_blobs.each do |blob|
        next unless blob.content_type.start_with?('application/pdf') || blob.content_type.start_with?('video/')
        sgid = blob.signed_id
        preview_url = preview_urls[sgid].presence || blob.metadata.with_indifferent_access['preview_url'].presence

        # Delegate to the shared helper so the exact same structure (with filename + size in the link text,
        # and consistent preview sizing) is used for new posts. The helper also does the server fallback.
        figure_html = helpers.attachment_figure_html(blob, preview_url: preview_url)

        # Capture preceding text (non-tag content right before the tag) and put figure first, then the text in a paragraph below.
        # This gives the desired order: attachment preview + centered link under it, then squak text paragraph below.
        pattern = /([^<]*?)(<action-text-attachment[^>]*sgid="#{Regexp.escape(sgid)}"[^>]*>.*?<\/action-text-attachment>)/m
        html = html.gsub(pattern) do
          pre_text = $1
          # $2 is the original tag, we discard it
          if pre_text.strip.present?
            "#{figure_html}<p>#{pre_text.strip}</p>"
          else
            figure_html
          end
        end
      end
      @squak.body.body = html if html != @squak.body.body.to_s
    end

    if @squak.save
      # Force a fresh load so we have the persisted RichText id.
      @squak.reload
      rich_text = @squak.rich_text_body

      processed_blobs.each do |blob|
        next unless rich_text
        # Use direct find_or_create_by on the attachment table to guarantee the linking row
        # (record_type ActionText::RichText, record_id = the rich text's own id, name 'embeds', the blob).
        # This is what the ActionText content renderer + sgid resolver uses to turn the
        # <action-text-attachment sgid=...> in the saved body into a real attachable (your blob)
        # so our PDF partials get called instead of _missing_attachable.
        # Using the association .attach was not resulting in a visible row in the logs even
        # after reload (stale proxy or integration detail with how the body was assigned).
        ActiveStorage::Attachment.find_or_create_by!(
          name: 'embeds',
          record_type: 'ActionText::RichText',
          record_id: rich_text.id,
          blob_id: blob.id
        )
      end

      embed_count = @squak.body.embeds.count rescue 0
      rich_text_embed_count = rich_text&.embeds&.reload&.count rescue 0
      Rails.logger.debug "Squak saved successfully. in-memory embeds count: #{embed_count}, rich_text_body embeds attachments: #{rich_text_embed_count} (we just attached #{processed_blobs.size} blob(s))"
      # squak = render_to_string(partial: "squaks/squak", locals: { squak: @squak }, formats: [:html], cache: false)
      # Broadcast to other subscribed clients asynchronously (no render_to_string needed)
      # Broadcast only to clients currently viewing this circle's list
      Turbo::StreamsChannel.broadcast_prepend_later_to(
        "circle-#{@squak.circle_id}-squaks",
        target: "squaks-list",
        partial: "squaks/squak",
        locals: { squak: @squak, user: current_user }
      )

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend(
              "squaks-list",
              partial: "squaks/squak",
              locals: { squak: @squak, user: current_user }
            )
          ]
        end
        format.html { redirect_to dashboard_path, notice: "Squak created" }
        format.json { head :ok }
      end
    else
      Rails.logger.error "Squak save failed: #{@squak.errors.full_messages}"
      respond_to do |format|
        format.turbo_stream do
          # Use the real form partial (in dashboard) so turbo error re-renders the composer
          # without hitting MissingTemplate. Pass circle_id so the hidden field is correct.
          circle_id = squak_params[:circle_id] if defined?(squak_params)
          render turbo_stream: [
            turbo_stream.replace(
              "squak-form",
              partial: "dashboard/squak_form",
              locals: { circle_id: circle_id, squak: @squak, errors: @squak.errors.full_messages }
            )
          ], status: :unprocessable_entity
        end
        format.html do
          flash.now[:alert] = @squak.errors.full_messages.to_sentence
          render :new, status: :unprocessable_entity
        end
        format.json do
          render json: { errors: @squak.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def squaks
    @circle_id = params.expect(:circle_id)&.to_i
    circle = (current_user.circles.find_by(id: @circle_id) ||
      current_user.circle_memberships.find_by(circle_id: @circle_id)&.circle)

    per_page = (params[:limit].presence || 20).to_i.clamp(5, 100)
    before_id = params[:before_id].presence&.to_i

    scope = Squak.for_circle(circle).reorder(id: :desc)
    scope = scope.where("id < ?", before_id) if before_id
    @page = scope.limit(per_page)

    respond_to do |format|
      format.turbo_stream do
        if before_id
          if @page.empty?
            head :no_content
          else
            render turbo_stream: turbo_stream.before(
              "squaks-sentinel",
              partial: "squaks/squak",
              collection: @page,
              as: :squak
            )
          end
        else
          render turbo_stream: turbo_stream.replace(
            "squak-view",
            partial: "squaks/turbo_squak_index",
            locals: { squaks: @page, circleId: @circle_id }
          )
        end
      end
      format.html do
        render partial: "squaks/squak_index", locals: { squaks: @page, circleId: @circle_id }
      end
    end
  end

  def destroy
    unless can_destroy?(@squak)
      return respond_to do |format|
        format.turbo_stream { head :forbidden }
        format.html { head :forbidden }
        format.json { head :forbidden }
      end
    end

    @squak.destroy
    target_id = "squak-#{@squak.id}"
    # Notify only viewers of this circle's list
    Turbo::StreamsChannel.broadcast_remove_to("circle-#{@squak.circle_id}-squaks", target: target_id)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(target_id) }
      format.html do
        response.headers["Content-Type"] = "text/vnd.turbo-stream.html"
        render turbo_stream: turbo_stream.remove(target_id)
      end
      format.json { head :ok }
    end
  end

  private

  def param_circle_id
    params.expect(:circle_id)
  end

  def getCircle
    circle_id = params.expect(:circle_id)&.to_i
    (current_user.circles.find_by(id: circle_id) ||
      current_user.circle_memberships.find_by(circle_id: circle_id)&.circle)
  end

  def set_squak
    @squak = Squak.find(params[:id])
  end

  def can_destroy?(squak)
    return false if squak.blank?
    return true if squak.user_id == current_user.id
    owner_id = squak.circle&.user_id
    owner_id.present? && owner_id == current_user.id
  end

  # Self-contained resolver so the critical create path does not depend on the
  # initializer monkey-patch or the class method being present. Tries plain
  # signed_id then the ActionText attachable signed GlobalID form.
  # Falls back to decoding the (possibly expired) signed GID payload to extract
  # the blob id, because attachable sgids embedded in submitted rich text often
  # have short expiries and locate_signed will fail after a few seconds.
  def safe_resolve_blob_from_sgid(sgid)
    return nil if sgid.blank?

    # 1. Plain ActiveStorage signed_id (what most DirectUpload paths provide)
    begin
      if (blob = ActiveStorage::Blob.find_signed(sgid))
        return blob
      end
    rescue ActiveRecord::RecordNotFound, NoMethodError
      # try next strategy
    end

    # 2. Signed GlobalID (the form that ends up in <action-text-attachment sgid="...">
    #    and in the data-trix-attachment JSON sgid field for images etc.)
    begin
      located = GlobalID::Locator.locate_signed(sgid)
      return located if located.is_a?(ActiveStorage::Blob)
      if located && located.respond_to?(:blob)
        b = located.blob
        return b if b.is_a?(ActiveStorage::Blob)
      end
    rescue => e
      Rails.logger.debug "safe_resolve_blob_from_sgid: locate_signed failed: #{e.class} #{e.message}"
    end

    # 3. Decode the signed GID payload (the part before --) to extract the inner
    #    gid://.../ActiveStorage::Blob/NN even if the signature has expired.
    #    This is the key fix for attachable sgids that were fresh when the
    #    user inserted the image but have a short expiry by the time the form
    #    is submitted + pre-save processing runs.
    if (id = self.class.extract_blob_id_from_sgid_payload(sgid))
      return ActiveStorage::Blob.find_by(id: id)
    end

    # 4. Last-ditch parse of a bare id
    if sgid.to_s =~ /\A\d+\z/
      return ActiveStorage::Blob.find_by(id: sgid.to_i)
    end

    nil
  end

  def self.extract_blob_id_from_sgid_payload(sgid)
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
      # invalid base64 or json — ignore
    end
    nil
  end
end
