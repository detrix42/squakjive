import consumer from "channels/consumer"

consumer.subscriptions.create("SquaksChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
    console.log("Connected to SquaksChannel")
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log("Disconnected from SquaksChannel")
  },

  received(data) {
    // Called when data is broadcast to this channel

    // const squakEditor = document.querySelector('#squak-editor')
    // if (squakEditor) {
    //   squakEditor.innerHTML = ''
    // }

    const previews =
        document.querySelector('[data-squakeditor-target=\'previews\']')
  },

});
