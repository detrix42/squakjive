// JavaScript
// app/javascript/controllers/trix_paste_utils.js

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
