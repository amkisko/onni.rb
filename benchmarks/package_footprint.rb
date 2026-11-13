# frozen_string_literal: true

require "bundler/setup"
require "json"
require "rubygems/package"
require "digest"
require "stringio"
require "zlib"
require "fileutils"

module PackageFootprint
  module_function

  def installed_size(specification)
    files = Dir.glob("**/*", File::FNM_DOTMATCH, base: specification.full_gem_path)
      .map { |path| File.join(specification.full_gem_path, path) }
      .select { |path| File.file?(path) }
    {"files" => files.size, "logical_bytes" => files.sum { |path| File.size(path) }}
  end

  def dependencies(specification)
    resolved = Bundler.load.specs.to_h { |entry| [entry.name, entry] }
    names = []
    queue = specification.runtime_dependencies.map(&:name)
    until queue.empty?
      name = queue.shift
      next if names.include?(name)

      entry = resolved.fetch(name)
      names << name
      queue.concat(entry.runtime_dependencies.map(&:name))
    end
    runtime = names.sort.to_h do |name|
      entry = resolved.fetch(name)
      [name, installed_size(entry).merge("version" => entry.version.to_s)]
    end
    development = resolved.values.reject { |entry| entry.name == specification.name }
    {"runtime" => runtime, "runtime_logical_bytes" => runtime.values.sum { |row| row.fetch("logical_bytes") },
     "checkout_graph_gems" => development.size,
     "checkout_graph_logical_bytes" => development.sum { |entry| installed_size(entry).fetch("logical_bytes") }}
  end

  def archive_parts(path)
    File.open(path, "rb") do |file|
      Gem::Package::TarReader.new(file).each_with_object({}) do |entry, result|
        next unless entry.file?

        compressed = entry.read
        raw = Zlib::GzipReader.wrap(StringIO.new(compressed), &:read)
        result[entry.full_name] = {"compressed_bytes" => compressed.bytesize, "uncompressed_bytes" => raw.bytesize}
      end
    end
  end

  def run(root)
    Dir.chdir(root) do
      specification = Gem::Specification.load("onni.gemspec")
      files = specification.files.select { |path| File.file?(path) }.sort
      digest = Digest::SHA256.new
      files.each { |path| digest << path << File.binread(path) }
      builds = 3.times.map do |index|
        path = File.expand_path(".footprint-#{index}.gem")
        previous_stdout = $stdout
        begin
          $stdout = StringIO.new
          Gem::Package.build(specification, false, false, path)
        ensure
          $stdout = previous_stdout
        end
        {"bytes" => File.size(path), "sha256" => Digest::SHA256.file(path).hexdigest}
      end
      archive = ".footprint-0.gem"
      extracted = File.expand_path("../#{File.basename(Dir.pwd)}-extracted")
      Gem::Package.new(archive).extract_files(extracted)
      {
        "source_digest" => digest.hexdigest,
        "gem_name" => specification.name, "version" => specification.version.to_s,
        "source_date_epoch" => ENV.fetch("SOURCE_DATE_EPOCH"),
        "builds" => builds, "reproducible" => builds.map { |row| row.fetch("sha256") }.uniq.one?,
        "archive_parts" => archive_parts(archive),
        "package_files" => files.size,
        "package_file_bytes" => files.sum { |path| File.size(path) },
        "by_directory" => files.group_by { |path| path.include?("/") ? path.split("/").first : "root" }
          .transform_values { |paths| {"files" => paths.size, "bytes" => paths.sum { |path| File.size(path) }} },
        "largest_files" => files.sort_by { |path| -File.size(path) }.first(12).to_h { |path| [path, File.size(path)] },
        "dependencies" => dependencies(specification)
      }
    end
  end
end

result = PackageFootprint.run(File.expand_path(ARGV.fetch(0, ".")))
destination = ARGV.fetch(1, "benchmarks/output/package_footprint.json")
FileUtils.mkdir_p(File.dirname(destination))
File.write(destination, JSON.pretty_generate(result) + "\n")
puts JSON.generate(result.slice("gem_name", "version", "builds", "reproducible", "package_files", "package_file_bytes", "by_directory"))
