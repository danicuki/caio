// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {Hooks as BackpexHooks} from "backpex"
// import {hooks as colocatedHooks} from "phoenix-colocated/portal"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...BackpexHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#0E5C49"}, shadowColor: "rgba(0, 0, 0, .2)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
// if (process.env.NODE_ENV === "development") {
//   window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
//     // Enable server log streaming to client.
//     // Disable with reloader.disableServerLogs()
//     reloader.enableServerLogs()
// 
//     // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
//     //
//     //   * click with "c" key pressed to open at caller location
//     //   * click with "d" key pressed to open at function component definition location
//     let keyDown
//     window.addEventListener("keydown", e => keyDown = e.key)
//     window.addEventListener("keyup", _e => keyDown = null)
//     window.addEventListener("click", e => {
//       if(keyDown === "c"){
//         e.preventDefault()
//         e.stopImmediatePropagation()
//         reloader.openEditorAtCaller(e.target)
//       } else if(keyDown === "d"){
//         e.preventDefault()
//         e.stopImmediatePropagation()
//         reloader.openEditorAtDef(e.target)
//       }
//     }, true)
// 
//     window.liveReloader = reloader
//   })
// }


// Handle flash close
document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
  el.addEventListener("click", () => {
    el.setAttribute("hidden", "")
  })
})

// Product analytics. PostHog is optional and configured from runtime env.
const posthogConfig = window.caioPosthogConfig

if (posthogConfig?.apiKey) {
  ;(function (t, e) {
    var o, n, p, r
    e.__SV ||
      ((window.posthog = e),
      (e._i = []),
      (e.init = function (i, s, a) {
        function g(t, e) {
          var o = e.split(".")
          o.length == 2 && ((t = t[o[0]]), (e = o[1]))
          t[e] = function () {
            t.push([e].concat(Array.prototype.slice.call(arguments, 0)))
          }
        }
        ;((p = t.createElement("script")).type = "text/javascript"),
          (p.async = !0),
          (p.src = s.api_host + "/static/array.js"),
          (r = t.getElementsByTagName("script")[0]).parentNode.insertBefore(p, r)
        var u = e
        for (
          void 0 !== a ? (u = e[a] = []) : (a = "posthog"),
            u.people = u.people || [],
            u.toString = function (t) {
              var e = "posthog"
              return "posthog" !== a && (e += "." + a), t || (e += " (stub)"), e
            },
            u.people.toString = function () {
              return u.toString(1) + ".people (stub)"
            },
            o =
              "capture identify alias people.set people.set_once set_config register register_once unregister opt_out_capturing has_opted_out_capturing opt_in_capturing reset isFeatureEnabled onFeatureFlags reloadFeatureFlags getFeatureFlag getFeatureFlagPayload group get_group_info groups setPersonPropertiesForFlags resetPersonPropertiesForFlags".split(
                " "
              ),
            n = 0;
          n < o.length;
          n++
        )
          g(u, o[n])
        e._i.push([i, s, a])
      }),
      (e.__SV = 1))
  })(document, window.posthog || [])

  posthog.init(posthogConfig.apiKey, {
    api_host: posthogConfig.apiHost,
    autocapture: posthogConfig.autocapture === true,
    capture_pageview: posthogConfig.capturePageview === true,
    capture_pageleave: false,
    capture_dead_clicks: false,
    capture_performance: false,
    rageclick: false,
    disable_surveys: true,
    mask_all_element_attributes: true,
    mask_personal_data_properties: true,
    session_recording: {
      maskAllInputs: true,
    },
    disable_session_recording: !posthogConfig.sessionReplay,
  })

  const distinctId = document.body.dataset.analyticsDistinctId
  if (distinctId) posthog.identify(distinctId)
}

const capture = (event, properties = {}) => {
  if (window.posthog?.capture) window.posthog.capture(event, properties)
}

const urlParams = new URLSearchParams(window.location.search)
const utmProperties = {}
;["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"].forEach((key) => {
  const value = urlParams.get(key)
  if (value) utmProperties[key] = value
})

if (Object.keys(utmProperties).length > 0) {
  capture("acquisition_landing", {
    path: window.location.pathname,
    ...utmProperties,
  })

  if (window.posthog?.register_once) {
    window.posthog.register_once(utmProperties)
  }
}

// Mobile navigation menu
document.querySelectorAll(".topbar").forEach((topbar) => {
  const button = topbar.querySelector(".mobile-menu-button")
  const menu = topbar.querySelector(".nav-menu")

  if (!button || !menu) return

  const setOpen = (open) => {
    topbar.classList.toggle("menu-open", open)
    button.setAttribute("aria-expanded", open ? "true" : "false")
  }

  button.addEventListener("click", () => {
    capture("mobile_menu_toggled", {
      open: !topbar.classList.contains("menu-open"),
    })
    setOpen(!topbar.classList.contains("menu-open"))
  })

  menu.querySelectorAll("a, button").forEach((item) => {
    item.addEventListener("click", () => setOpen(false))
  })

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setOpen(false)
  })

  document.addEventListener("click", (event) => {
    if (!topbar.contains(event.target)) setOpen(false)
  })
})

document.querySelectorAll("form[action='/jobs']").forEach((form) => {
  form.addEventListener("submit", () => {
    const data = new FormData(form)
    capture("jobs_search_submitted", {
      q: data.get("q"),
      role: data.get("role"),
      company: data.get("company"),
      location: data.get("location"),
      order: data.get("order"),
    })
  })
})

document.querySelectorAll("[data-copy-search-url]").forEach((button) => {
  button.addEventListener("click", async () => {
    const url = window.location.href

    try {
      await navigator.clipboard.writeText(url)
      button.textContent = "Copied"
      window.setTimeout(() => {
        button.textContent = "Copy search link"
      }, 1600)
      capture("search_link_copied", {
        label: button.dataset.shareLabel,
        path: window.location.pathname,
        query: window.location.search,
      })
    } catch (_error) {
      capture("search_link_copy_failed", {
        label: button.dataset.shareLabel,
        path: window.location.pathname,
      })
    }
  })
})

document.querySelectorAll("[data-agent-cta]").forEach((link) => {
  link.addEventListener("click", () => {
    capture("agent_cta_clicked", {
      cta: link.dataset.agentCta,
      path: window.location.pathname,
    })
  })
})

document.querySelectorAll("[data-acquisition-link]").forEach((link) => {
  link.addEventListener("click", () => {
    capture("acquisition_link_clicked", {
      kind: link.dataset.acquisitionLink,
      href: link.getAttribute("href"),
      path: window.location.pathname,
    })
  })
})

document.querySelectorAll(".profile-modal").forEach((modal) => {
  if (window.location.hash === `#${modal.id}`) {
    capture("profile_modal_opened", { modal_id: modal.id })
  }
})

document.querySelectorAll("a[href^='#unlock'], a[href^='#apply-profile']").forEach((link) => {
  link.addEventListener("click", () => {
    capture("profile_modal_opened", {
      target: link.getAttribute("href")?.replace("#", ""),
    })
  })
})

document.querySelectorAll("a[href^='/auth/github']").forEach((link) => {
  link.addEventListener("click", () => capture("github_login_clicked"))
})

document.querySelectorAll("form[action$='/apply']").forEach((form) => {
  form.addEventListener("submit", () => capture("job_apply_submitted"))
})

// Founder chat. A tiny polling widget keeps the launch feedback loop direct
// without requiring Phoenix channels yet.
document.querySelectorAll("[data-founder-chat]").forEach((widget) => {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  const toggle = widget.querySelector("[data-chat-toggle]")
  const close = widget.querySelector("[data-chat-close]")
  const panel = widget.querySelector(".founder-chat-panel")
  const form = widget.querySelector("[data-chat-form]")
  const textarea = form?.querySelector("textarea[name='body']")
  const messagesEl = widget.querySelector("[data-chat-messages]")
  const empty = widget.querySelector(".founder-chat-empty")

  if (!csrfToken || !toggle || !panel || !form || !textarea || !messagesEl) return

  let conversationId = null
  let lastMessageId = 0
  let pollTimer = null
  let starting = null

  widget.hidden = false

  const request = async (path, options = {}) => {
    const response = await fetch(path, {
      credentials: "same-origin",
      headers: {
        "content-type": "application/json",
        "x-csrf-token": csrfToken,
        ...(options.headers || {}),
      },
      ...options,
    })

    if (!response.ok) throw new Error(`Chat request failed: ${response.status}`)
    return response.json()
  }

  const setOpen = async (open) => {
    widget.classList.toggle("open", open)
    toggle.setAttribute("aria-expanded", open ? "true" : "false")

    if (open) {
      await ensureConversation()
      textarea.focus()
      startPolling()
      capture("founder_chat_opened")
    } else {
      stopPolling()
    }
  }

  const ensureConversation = async () => {
    if (conversationId) return conversationId
    if (starting) return starting

    starting = request("/chat/conversations", {
      method: "POST",
      body: JSON.stringify({ path: window.location.pathname + window.location.search }),
    })
      .then((payload) => {
        conversationId = payload.conversation?.id
        appendMessages(payload.messages || [])
        return conversationId
      })
      .finally(() => {
        starting = null
      })

    return starting
  }

  const startPolling = () => {
    stopPolling()
    pollTimer = window.setInterval(loadMessages, 2500)
    loadMessages()
  }

  const stopPolling = () => {
    if (pollTimer) window.clearInterval(pollTimer)
    pollTimer = null
  }

  const loadMessages = async () => {
    if (!conversationId) return

    try {
      const payload = await request(`/chat/messages?after_id=${lastMessageId}`, {
        method: "GET",
        headers: { "content-type": "application/json" },
      })
      appendMessages(payload.messages || [])
    } catch (_error) {
      stopPolling()
    }
  }

  const appendMessages = (messages) => {
    messages.forEach((message) => {
      if (message.id <= lastMessageId) return

      empty?.remove()
      lastMessageId = Math.max(lastMessageId, message.id)

      const bubble = document.createElement("div")
      bubble.className = `founder-chat-message ${message.direction}`
      bubble.textContent = message.body
      messagesEl.appendChild(bubble)
      messagesEl.scrollTop = messagesEl.scrollHeight
    })
  }

  toggle.addEventListener("click", () => setOpen(!widget.classList.contains("open")))
  close?.addEventListener("click", () => setOpen(false))

  form.addEventListener("submit", async (event) => {
    event.preventDefault()
    const body = textarea.value.trim()
    if (!body) return

    textarea.value = ""
    textarea.disabled = true

    try {
      await ensureConversation()
      const payload = await request("/chat/messages", {
        method: "POST",
        body: JSON.stringify({ message: { body } }),
      })
      appendMessages(payload.message ? [payload.message] : [])
      capture("founder_chat_message_sent")
      startPolling()
    } catch (_error) {
      textarea.value = body
    } finally {
      textarea.disabled = false
      textarea.focus()
    }
  })
})
