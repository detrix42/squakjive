import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

static values = {
    circleId: {
      type: Number
    },
    userId: {
      type: Number
    }
  }

  connect() {
  }

  async remove_member() {
    const url = '/circle_memberships'
    const data = {circle_membership: {
        circle_id: this.circleIdValue,
        user_id: this.userIdValue
      }
    }
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    if (confirm('Are you sure you want to remove this user from this circle?')) {
      try {
        const res = await fetch(url, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/vnd.turbo-stream.html',
            'X-CSRF-Token': csrfToken
          },
          body: JSON.stringify(data)
        })
        if (res.ok) {
          const resText = await res.text()
          console.log('resText:', resText)
          Turbo.renderStreamMessage(resText)

          const user_to_remove =
              document.querySelector(`#sidebar-user-item-${this.userIdValue}`)
          user_to_remove.remove()

        } else {
          alert('Error removing user from circle')
        }
      } catch (error) {
        alert('Network error removing user from circle')
      }

    }
  }

  remove_self_from_circle = async (event) => {
    event.preventDefault()
    event.stopPropagation()

    const circleId = event.currentTarget.dataset.circlesCircleId
    if (!circleId) return

    if (!confirm("Leave this circle?")) return

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]').content
      const resp = await fetch("/circle_memberships/self", {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrf,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ circle_id: circleId }),
        credentials: "same-origin"
      })

      if (!resp.ok) {
        console.warn("Failed to leave circle", await resp.text())
        return
      }

      const html = await resp.text()
      if (html && html.includes("<turbo-stream")) {
        Turbo.renderStreamMessage(html)
      }
    } catch (e) {
      console.error("Network error leaving circle", e)
    }
  }


}
