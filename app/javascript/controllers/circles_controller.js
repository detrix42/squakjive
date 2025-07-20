import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["selector", "display"]

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
        detail: { circleName: this.circleNameValue,
                  circleId: this.selectedCircleIdValue},
        bubbles: true
      });
      window.dispatchEvent(circEvent);  // Global dispatch
    }

    if (this.circleRoleValue === 'editor') {
      this.element.innerHTML = this.circleNameValue
      this.element.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
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
    if (this.circleRoleValue === 'display') {
      this.element.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }
  }

  handleCircleSelection = (event) => {

    if (this.circleRoleValue === 'selector') {
      // Remove 'selected' class from currently selected circle
      const currentlySelected = this.element.querySelector('.selected')
      if (currentlySelected) {
        currentlySelected.classList.remove('selected')
      }

      // highlight the selected (active) circle
      const tgt = this.element.querySelector(`#circle-id-${this.selectedCircleIdValue}`)
      tgt.classList.add('selected')

      // send event so another circle controller can react.
      this.dispatchCircleEvent(this.circleNameValue)
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
    // Only run if this is the selector instance
    if (this.roleValue !== "selector") return;

    // Get circle_id from the clicked element
    const circleId = event.currentTarget.dataset.circleId;
    console.log(`Selected circle_id: ${circleId}`);

    // Create and dispatch a custom event with circle_id in detail
    const customEvent = new CustomEvent("circle:selected", {
      detail: { circleId: circleId },
      bubbles: true  // Allows bubbling if needed, but we're using window
    });
    window.dispatchEvent(customEvent);  // Global dispatch
  }

  dispatchCircleEvent(circleName) {
    const circEvent = new CustomEvent("circle-selection:circleSelected", {
      detail: { circleName: circleName },
      bubbles: true
    });
    window.dispatchEvent(circEvent)
  }

}
