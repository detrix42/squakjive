import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["selector", "display", 'item', 'userList']

  static values = {
    selectedCircleId: {
      type: Number,
      defaultValue: null,
      nullable: true
    },
    circleRole: {
      type: String,
      default: ''
    },
    circleName: {
      type: String,
      default: 'No Circle Selected'
    },
    circleId: Number,
  }

  connect() {
    if(this.selectedCircleIdValue === null) {
      return;
    }

    const tgt = this.element.querySelector(`#circle-id-${this.selectedCircleIdValue}`)
    if (tgt && !tgt.classList.contains('selected')) {
      tgt.classList.add('selected')
    }

    if (this.circleRoleValue === 'selector') {
      const circEvent = new CustomEvent("circle-selection:circleSelected", {
        detail: {
          circleName: this.circleNameValue,
          circleId: this.selectedCircleIdValue
        },
        bubbles: true
      });
      window.dispatchEvent(circEvent);  // Global dispatch
    }

    if (this.circleRoleValue === 'squak_to_display') {

      this.element.innerHTML = this.circleNameValue
      window.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }


  }

  disconnect() {
    if (this.circleRoleValue === 'editor') {
      window.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }


    if (this.circleRoleValue === 'squak_to_display') {
      this.element.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }
  }

  handleCircleSelection = async (event) => {
    console.log("handle circle selection", event.detail);
    if (this.circleRoleValue === "selector") {
      console.log('circle_controller#handleCircleSelection: selector')

      this.changeSelectedCircle(this.selectedCircleIdValue, this);
      const circleId = event.detail.circleId || 0;
      Turbo.visit(`/squaks/${circleId}`, {
        frame: "squak-view",
        headers: { Accept: "text/vnd.turbo-stream.html" }  // Ensure Turbo Stream
      });
    }

    if (this.circleRoleValue === "display") {
      console.log('circle_controller#handleCircleSelection: display')

      const tgt = this.element.querySelector(`#editor-circle-name`);
      if (tgt) {

        tgt.innerHTML = event.detail.circleName;
      }

      try {
        const squak_res = await fetch(`/squaks/${circleId}`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/vnd.turbo-stream.html',
          }
        })
        if (squak_res.ok) {
          const squak_res_text = await squak_res.text()
          Turbo.renderStreamMessage(squak_res_text)
        }
      } catch (error) {
        console.log('network error-> select circle error:', error)
      }
    }

    if (this.circleRoleValue === "editor") {
      this.element.innerHTML = event.detail.circleName;
    }
  }

  // Action: Called on click in the selector's <li>
  async select(event) {
    const circleId = event.currentTarget.dataset.circlesCircleId || 0;
    const circleName = event.currentTarget.dataset.circlesCircleName;

    this.changeSelectedCircle(circleId, this)
    this.toggleList(event)

    const form_circle_id = document.querySelector('input[name="squak[circle_id]"]');
    if (form_circle_id) {
      form_circle_id.value = circleId;
    }

    try {
      const squaks_res = await fetch(`/squaks/${circleId}`, {
        headers: {Accept: "text/vnd.turbo-stream.html"}  // Ensure Turbo Stream
      });
      if (squaks_res.ok) {
        const squaks_res_text = await squaks_res.text();
        Turbo.renderStreamMessage(squaks_res_text);
      }
    } catch (error) {
      console.log('network error-> select circle error:', error)
    }


    const customEvent = new CustomEvent("circle-selection:circleSelected", {
      detail: {
        circleName: circleName,
        circleId: circleId
      },
      bubbles: true
    });
    window.dispatchEvent(customEvent);

    try {
      const res = await fetch('/user_profile/update_selected_circle', {
        method: 'PATCH',
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({circle_id: circleId})
      })
      if (res.ok) {
        console.log('User profile; update selected circle to:', circleName)
      } else {
        console.log('Error updating user profile selected circle')
      }
    } catch (error) {
      console.log('network error-> update selected circle error:', error)
    }

  }


  dispatchCircleEvent(circleName) {
    const circEvent = new CustomEvent("circle-selection:circleSelected", {
      detail: {circleName: circleName},
      bubbles: true
    });
    window.dispatchEvent(circEvent)
  }

  changeSelectedCircle(circleID, tgtElement) {
    const currentlySelected = this.element.querySelector('.selected');

    if (currentlySelected) {
      const uList = currentlySelected.querySelector('.circle-user-list');
      if (uList && uList.classList.contains('expanded')) {
        uList.style.maxHeight = uList.scrollHeight + 'px';
        requestAnimationFrame(() => {
          uList.style.maxHeight = '0px';
        });
        uList.classList.remove('expanded');
      }
      currentlySelected.classList.remove('selected');
    }

    const tgt = tgtElement.element.querySelector(`#circle-id-${circleID}`);
    tgt.classList.add('selected');

  }

  add_user(event) {
    event.stopPropagation()
    const circleId = event.target.closest('.circle-item').dataset.circlesCircleId

    // Load the modal content
    Turbo.visit(`/circles/${circleId}/add_user_modal`, { frame: "circle-add-user-modal" })
  }

  closeAddUserModal() {
    console.log('close add user modal')
    const modal = document.getElementById("circle-add-user-modal")
    modal.innerHTML = ""
  }

  toggleList(event) {
    const circleId = event.currentTarget.dataset.circlesCircleId;
    const li = event.currentTarget;  // The clicked <li>
    const el = document.querySelector(`#circle-user-list-${circleId}`);  // Specific <ul>
    if (!el) {
      console.error("No user-list target found in this <li>", li);
      return;
    }

    console.log("Toggling userList:", el);  // Debug
    if (!el.classList.contains('expanded')) {
      el.style.maxHeight = el.scrollHeight + 'px';
      el.classList.add('expanded');
      el.addEventListener('transitionend', () => {
        el.style.maxHeight = 'none';
      }, { once: true });
    }

  }

  async remove_circle(event) {
    event.preventDefault()
    event.stopPropagation()

    console.log('remove circle with id:', event.currentTarget.dataset.circlesCircleId)
    const id = event.currentTarget.dataset.circlesCircleId
    const name = this.circleNameValue || "(unnamed circle)"

    if (!id) return

    if (!confirm(`Remove circle "${name}"?\n This cannot be undone.`)) return

    const csrfTkn = document.querySelector('meta[name="csrf-token"]').content

    const resp = await fetch(`/circles/${id}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfTkn,
        "Accept": "text/vnd.turbo-stream.html"
      },
      credentials: "same-origin"
    })

    if (!resp.ok) {
      // Optionally show an error message
      return
    }

    // IMPORTANT: manually apply the Turbo Stream message
    const html = await resp.text()
    if (html && html.includes("<turbo-stream")) {
      Turbo.renderStreamMessage(html)
    } else {
      // Fallback if not a stream: remove the element manually
      const li = document.getElementById(`circle-id-${id}`)
      li && li.remove()
    }


    // If the server responds with a Turbo Stream, Turbo will apply it.
    // Otherwise, you could manually remove the element:
    // this.element.remove()


  }


}
