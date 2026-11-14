# frozen_string_literal: true

require "rake"
require "onni"

namespace :onni do
  export = lambda do |format|
    output = Onni.export_catalogue(format: format)
    path = ENV["OUTPUT"]
    (path && !path.empty?) ? File.write(path, output) : $stdout.write(output)
  end

  desc "Export the feature catalogue (FORMAT=yaml|json|csv, OUTPUT=path)"
  task :export do
    export.call(ENV.fetch("FORMAT", "yaml"))
  end

  %w[yaml json csv].each do |format|
    desc "Export the feature catalogue as #{format.upcase} (OUTPUT=path)"
    task "export_#{format}" do
      export.call(format)
    end
  end
end
