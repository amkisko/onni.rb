# frozen_string_literal: true

require "bundler/setup"
require "fileutils"
require "json"

root = File.expand_path("../..", __dir__)
dummy = File.join(root, "spec/dummy")
active_admin = Gem::Specification.find_by_name("activeadmin").full_gem_path
build = File.join(dummy, "tmp/admin-assets")
public_path = File.join(dummy, "public")
FileUtils.mkdir_p([build, File.join(public_path, "stylesheets")])

FileUtils.cp(File.join(active_admin, "plugin.js"), File.join(build, "plugin.mjs"))
sources = [
  "#{active_admin}/app/views/**/*.{arb,erb,html,rb}",
  "#{active_admin}/lib/**/*.rb",
  "#{active_admin}/vendor/javascript/*.js",
  "#{root}/app/**/*.{arb,erb,html,rb}",
  "#{dummy}/app/**/*.{arb,erb,html,rb}"
]
File.write(File.join(build, "tailwind.config.mjs"), <<~JAVASCRIPT)
  import activeAdminPlugin from "./plugin.mjs";
  export default {
    content: #{JSON.generate(sources)},
    darkMode: "selector",
    plugins: [activeAdminPlugin]
  };
JAVASCRIPT
input = File.join(build, "active_admin.css")
File.write(input, <<~CSS)
  @import "tailwindcss" source(none);
  @config "./tailwind.config.mjs";
CSS
executable = File.join(dummy, "node_modules/.bin/tailwindcss")
abort "Run npm --prefix spec/dummy ci first" unless File.executable?(executable)
abort "ActiveAdmin stylesheet build failed" unless system(
  executable, "--input", input,
  "--output", File.join(public_path, "stylesheets/active_admin.css"), "--minify"
)

Dir[File.join(active_admin, "{app,vendor}/javascript/*")].each do |path|
  FileUtils.cp_r(path, public_path)
end
