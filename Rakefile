require 'securerandom'

task default: :build_image

IMAGE_NAME = 'heapchart'
DOCKER = 'sudo -g docker docker'
# This file enumerates all files we want to be visible to Docker.  All other
# files are ignored and cannot be referenced in the Dockerfile.
MANIFEST = "MANIFEST"

# Let all relative paths be from the directory with the Rakefile.
Dir.chdir(File.dirname(__FILE__))

DATA_DIR = "data"
SESSION_SECRET = "data/session_secret"
DOCKERIGNORE = ".dockerignore"
# manually run `rake data/postgres`
POSTGRES_SECRET = "data/postgres"

desc "run the HeapChart server directly in the current shell"
task local: [SESSION_SECRET] do
  sh "ruby main.rb"
end

desc "run the HeapChart server as a Docker container"
task contained: [:build_image, SESSION_SECRET] do
  sh "#{DOCKER} run -p 80:22000 --volume ${PWD}/data:/heapchart/data #{IMAGE_NAME}"
end


desc "build the Docker image containing the server environment"
task build_image: [DOCKERIGNORE] do
  sh "#{DOCKER} build -t #{IMAGE_NAME} ."
end

file DATA_DIR do
  Dir.mkdir DATA_DIR
end

desc "generate the HMAC key for the session cookie's integrity"
file SESSION_SECRET => [DATA_DIR]  do
  unless File.exist?(SESSION_SECRET)
    File.open(SESSION_SECRET, 'w') { _1.puts SecureRandom.hex(64) }
  end
end

desc ("generate an opt-in dockerignore from the contents of #{MANIFEST}")
# Otherwise, all files in the directory get sent to the Docker daemon even if
# they aren't referenced in the Dockerfile.
file DOCKERIGNORE => [MANIFEST] do
  manifest = File.open MANIFEST
  dockerignore = File.open DOCKERIGNORE, 'w'

  # Exclude all files by default.
  dockerignore.puts "# auto-generated: do not edit; use #{MANIFEST}"
  dockerignore.puts "**/*"
  # Opt the files we want back in as exceptions.
  manifest.readlines
          .map(&:strip)
          .reject { /^#/ =~ _1 }
          .map { "!#{_1}\n" }
          .each { dockerignore << _1 }
ensure
  manifest.close
  dockerignore.close
end

desc "run `rake #{POSTGRES_SECRET}` to generate a suitable postgres password"
file POSTGRES_SECRET => [DATA_DIR] do
  unless File.exist?(POSTGRES_SECRET)
    File.open(POSTGRES_SECRET, 'w') { _1.puts SecureRandom.hex(16) }
  end
end
