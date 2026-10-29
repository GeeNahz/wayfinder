// Turnstile: renders Cloudflare's spam-check widget inside a form.
//
// The widget adds a hidden "cf-turnstile-response" input to the form, which
// the LiveView sends to Wayfinder.Turnstile.verify/2 on submit. Tokens can
// only be checked once, so the LiveView sends "turnstile:reset" after each
// attempt to get a fresh one.
//
// Cloudflare doesn't allow bundling their script, so we load it from their
// servers the first time a widget is needed.
//
// Usage: <div id="..." phx-hook="Turnstile" phx-update="ignore" data-sitekey="..."></div>

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let scriptLoading = null

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)

  scriptLoading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT_URL
    script.async = true
    script.onload = () => resolve(window.turnstile)
    script.onerror = reject
    document.head.appendChild(script)
  })

  return scriptLoading
}

export default {
  mounted() {
    loadTurnstile().then((turnstile) => {
      this.widgetId = turnstile.render(this.el, {
        sitekey: this.el.dataset.sitekey,
        theme: document.documentElement.dataset.theme === "dark" ? "dark" : "light",
      })
    })

    this.handleEvent("turnstile:reset", () => {
      if (this.widgetId !== undefined) window.turnstile.reset(this.widgetId)
    })
  },

  destroyed() {
    if (this.widgetId !== undefined) window.turnstile.remove(this.widgetId)
  },
}
