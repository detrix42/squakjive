// JavaScript
// app/javascript/controllers/trix_paste_utils.js

// Turbo may leave success unset for 200 turbo-stream responses (no redirect).
export function turboSubmitSucceeded(event) {
  return event.detail?.success !== false
}

export function getClipboardImageItems(event) {
  const cd = event.clipboardData || event.paste
  if (!cd || !cd.items) return []
  return Array.from(cd.items).filter(i => i.kind === "file" && i.type.startsWith("image/"))
}

export function getPastedText(event) {
  try {
    if (event?.paste && typeof event.paste.getData === "function") {
      return event.paste.getData("text/plain") || event.paste.getData("text") || ""
    }
    if (event?.clipboardData && typeof event.clipboardData.getData === "function") {
      return event.clipboardData.getData("text/plain") || ""
    }
    if (window.clipboardData && typeof window.clipboardData.getData === "function") {
      return window.clipboardData.getData("Text") || ""
    }
  } catch (e) {
    console.warn("Failed to read pasted text:", e)
  }
  return ""
}

export function isUrl(text) {
  const urlPattern = /^(https?:\/\/)?((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|((\d{1,3}\.){3}\d{1,3}))(:\d+)?(\/[-a-z\d%_.~+]*)*(\?[;&a-z\d%_.~+=-]*)?(#[-a-z\d_]*)?$/i
  return urlPattern.test(text.trim())
}

const TYPED_URL_PATTERN = /\bhttps?:\/\/[^\s<>"')]+/gi
const TRAILING_URL_PUNCTUATION = /[.,;:!?)]+$/

export function extractTypedUrls(text) {
  const urls = []
  let match

  while ((match = TYPED_URL_PATTERN.exec(text)) !== null) {
    let urlText = match[0].replace(TRAILING_URL_PUNCTUATION, "")
    const end = match.index + urlText.length

    if (end >= text.length || !/\s/.test(text[end])) continue
    if (!isUrl(urlText)) continue

    urls.push({ urlText, start: match.index, end })
  }

  return urls
}
