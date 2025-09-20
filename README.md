# things that need to be installed

- mu-tools
  - sudo apt-get install mu-tools
  - add the following to app/config/application.rb
    - config.active_storage.previewers << ActiveStorage::Previewer::MuPDFPreviewer
  - add the following system package
    - sudo apt install libvips 
    - 

