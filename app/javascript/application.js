// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import 'govuk-frontend'

document.addEventListener('DOMContentLoaded', () => {
  GOVUKFrontend.initAll();
})
