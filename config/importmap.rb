# Pin npm packages by running ./bin/importmap

pin "application"
pin_all_from "app/javascript/lib", under: "lib"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true

pin "tom-select", to: "tom-select.js", preload: false
pin "libphonenumber", to: "libphonenumber.js", preload: false
