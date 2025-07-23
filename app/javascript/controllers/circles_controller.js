import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["selector", "display", 'item']

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
    console.log('handle circle selection', event.detail)
    if (this.circleRoleValue === 'selector') {
      // Remove the dispatchCircleEvent call, just handle the selection
      this.changeSelectedCircle(this.selectedCircleIdValue, this)
    }


    if (this.circleRoleValue === 'display') {
      const tgt = this.element.querySelector(`#editor-circle-name`)
      if (tgt) {
        tgt.innerHTML = event.detail.circleName || 'All Circles'
      }

    }

    if (this.circleRoleValue === 'editor') {
      this.element.innerHTML = event.detail.circleName
    }
  }

  // Action: Called on click in the selector's <li>
  select(event) {
    const circleId = event.currentTarget.dataset.circlesCircleId;
    const circleName = event.currentTarget.dataset.circlesCircleName;
    this.changeSelectedCircle(circleId, this)

    const customEvent = new CustomEvent("circle-selection:circleSelected", {
      detail: {
        circleName: circleName,
        circleId: circleId  // Fixed variable name
      },
      bubbles: true
    });
    window.dispatchEvent(customEvent);
  }


  dispatchCircleEvent(circleName) {
    const circEvent = new CustomEvent("circle-selection:circleSelected", {
      detail: {circleName: circleName},
      bubbles: true
    });
    window.dispatchEvent(circEvent)
  }

  changeSelectedCircle(circleID, tgtElement) {
    const currentlySelected = this.element.querySelector('.selected')

    if (currentlySelected) {
      const uList = currentlySelected.querySelector('.circle-user-list')
      currentlySelected.classList.remove('selected')
    }

    const tgt = tgtElement.element.querySelector(`#circle-id-${circleID}`)
    tgt.classList.add('selected')

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




}
