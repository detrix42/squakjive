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
      default: 'All Circles'
    }
  }

  connect() {
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

    if (this.circleRoleValue === 'editor') {
      this.element.innerHTML = this.circleNameValue
      window.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }

    if (this.circleRoleValue === 'display') {
      const tgtName = this.element.querySelector(`#editor-circle-name`)
      if (tgtName) {
        tgtName.innerHTML = this.circleNameValue || 'All Circles'
      }
      this.element.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }


  }

  disconnect() {
    if (this.circleRoleValue === 'editor') {
      window.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }


    if (this.circleRoleValue === 'display') {
      this.element.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }
  }

  handleCircleSelection = (event) => {
    console.log("handle circle selection", event.detail);
    if (this.circleRoleValue === "selector") {
      this.changeSelectedCircle(this.selectedCircleIdValue, this);
    }

    if (this.circleRoleValue === "display") {
      const circleId = event.detail.circleId || 0;
      const tgt = this.element.querySelector(`#editor-circle-name`);
      if (tgt) {
        tgt.innerHTML = event.detail.circleName || "All Circles";
      }  // Ensure 0 for All Circles
      Turbo.visit(`/circles/${circleId}/squaks`, { frame: "squak-view" });
    }

    if (this.circleRoleValue === "editor") {
      this.element.innerHTML = event.detail.circleName;
    }
  }

  // Action: Called on click in the selector's <li>
  async select(event) {
    const circleId = event.currentTarget.dataset.circlesCircleId;
    const circleName = event.currentTarget.dataset.circlesCircleName;

    this.changeSelectedCircle(circleId, this)
    this.toggleList(event)

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


}
