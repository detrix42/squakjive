import "trix"
import "@rails/actiontext"

import "@hotwired/turbo-rails"
import "controllers"
import "channels"

const PREVIEW_LINK_SELECTOR = [
  "a.link-preview-youtube",
  ".link-preview a.card-title[href]",
  ".link-preview-thumbnail--wide"
].join(", ")

function findPreviewLink(target) {
  if (!(target instanceof Element)) return null

  const direct = target.closest(PREVIEW_LINK_SELECTOR)
  if (direct instanceof HTMLAnchorElement && direct.href) return direct

  const youtube = target.closest(".link-preview-youtube")
  if (youtube instanceof HTMLAnchorElement && youtube.href) return youtube

  const thumbnail = target.closest(".link-preview-thumbnail--wide")
  if (thumbnail) {
    const parentLink = thumbnail.closest("a[href]")
    if (parentLink instanceof HTMLAnchorElement && parentLink.href) return parentLink
  }

  return null
}

document.addEventListener("click", (event) => {
  const link = findPreviewLink(event.target)
  if (!link) return

  const href = link.getAttribute("href")
  if (!href || href === "#") return

  event.preventDefault()
  event.stopPropagation()
  window.open(href, "_blank", "noopener,noreferrer")
}, true)

Trix.config.attachments.preview.caption = {
  name: false,
  size: false
}


// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()


