// Notification sound from public/sounds/new_message_alert.wav, with Web Audio fallback.
// Browsers require a user gesture before audio can play; we unlock on first interaction.

const ALERT_SOUND_URL = "/sounds/new_message_alert.wav"
const FALLBACK_TONE_VOLUME = 0.27

let sharedBlip = null

export function getAlertBlip() {
  if (!sharedBlip) {
    sharedBlip = new AlertBlip()
  }
  return sharedBlip
}

class AlertBlip {
  constructor() {
    this.audioContext = null
    this.audioTemplate = null
    this.unlocked = false
    this.lastPlayedAt = 0
    this.bindUnlock()
  }

  bindUnlock() {
    const unlock = async () => {
      if (this.unlocked) return

      const AudioContext = window.AudioContext || window.webkitAudioContext
      if (AudioContext) {
        this.audioContext = new AudioContext()
        await this.audioContext.resume().catch(() => {})
      }

      this.audioTemplate = new Audio(ALERT_SOUND_URL)
      this.audioTemplate.preload = "auto"
      this.audioTemplate.load()

      // Prime playback during the user gesture so later alerts are not blocked.
      try {
        this.audioTemplate.volume = 0.01
        await this.audioTemplate.play()
        this.audioTemplate.pause()
        this.audioTemplate.currentTime = 0
        this.audioTemplate.volume = 1
      } catch (_) {
        // HTML5 audio may still be blocked; Web Audio fallback remains available.
      }

      this.unlocked = true
    }

    const options = { capture: true, passive: true }
    document.addEventListener("click", unlock, options)
    document.addEventListener("keydown", unlock, options)
    document.addEventListener("touchstart", unlock, options)
  }

  play() {
    if (!this.unlocked) return

    const now = Date.now()
    if (now - this.lastPlayedAt < 650) return
    this.lastPlayedAt = now

    // Background tabs usually block HTML5 audio; try Web Audio first there.
    if (document.hidden) {
      this.playFallback()
      return
    }

    this.playHtml5()
  }

  playHtml5() {
    if (!this.audioTemplate) {
      this.playFallback()
      return
    }

    const audio = this.audioTemplate.cloneNode()
    audio.volume = 1
    audio.play().catch(() => this.playFallback())
  }

  async playFallback() {
    if (!this.audioContext) return

    const ctx = this.audioContext
    if (ctx.state === "suspended") {
      await ctx.resume().catch(() => {})
    }

    const toneDuration = 0.3
    const start = ctx.currentTime

    this.playTone(ctx, 880, start, toneDuration)
    this.playTone(ctx, 1080, start + toneDuration, toneDuration)
  }

  playTone(ctx, frequency, startTime, duration, volume = FALLBACK_TONE_VOLUME) {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    const attack = 0.02
    const release = 0.04

    oscillator.type = "sine"
    oscillator.frequency.value = frequency

    gain.gain.setValueAtTime(0.0001, startTime)
    gain.gain.exponentialRampToValueAtTime(volume, startTime + attack)
    gain.gain.setValueAtTime(volume, startTime + duration - release)
    gain.gain.exponentialRampToValueAtTime(0.0001, startTime + duration)

    oscillator.connect(gain)
    gain.connect(ctx.destination)

    oscillator.start(startTime)
    oscillator.stop(startTime + duration + 0.01)
  }
}