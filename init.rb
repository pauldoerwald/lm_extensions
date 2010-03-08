require 'lm_extensions'

# Copy stylesheets to the right place
FileUtils.cp(
  Dir[File.join(File.dirname(__FILE__), 'stylesheets', '*')],
  File.join(RAILS_ROOT, 'public', 'stylesheets')
)
