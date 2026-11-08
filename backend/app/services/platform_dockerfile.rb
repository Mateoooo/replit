class PlatformDockerfile
  ARCHIVE_APT_FIX = %q(RUN if grep -qE 'buster|stretch' /etc/os-release; then sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g; /-updates/d' /etc/apt/sources.list && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive; fi).freeze

  START_COMMAND = 'CMD ["sh", "-c", "rm -f tmp/pids/server.pid && (bundle exec rails db:prepare || bundle exec rails db:create db:migrate) && exec bundle exec rails server -b 0.0.0.0 -p 3000"]'.freeze

  def initialize(root)
    @root = root.to_s
  end

  def write
    File.write(File.join(@root, "Dockerfile.platform"), render)
  end

  def render
    lines = []
    lines << "FROM ruby:#{ruby_version}"
    lines << ARCHIVE_APT_FIX
    lines << "RUN apt-get update -qq && apt-get install -y --no-install-recommends #{packages.join(' ')} && rm -rf /var/lib/apt/lists/*"
    lines << "RUN apt-get update -qq && (apt-get install -y --no-install-recommends libvips || true) && rm -rf /var/lib/apt/lists/*"
    lines << "RUN npm install -g yarn || true" if js?
    lines << "RUN gem install bundler -N || true"
    lines << "WORKDIR /app"
    lines.concat(layered? ? layered_install : simple_install)
    lines << "ENV RAILS_ENV=development"
    lines << "RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile || true"
    lines << "EXPOSE #{DockerRunner::APP_PORT}"
    lines << START_COMMAND
    lines.join("\n") + "\n"
  end

  def ruby_version
    @ruby_version ||= begin
      file = File.join(@root, ".ruby-version")
      version = File.exist?(file) ? File.read(file)[/\d+\.\d+(\.\d+)?/] : nil
      version || "3.3"
    end
  end

  def js?
    File.exist?(File.join(@root, "package.json"))
  end

  def layered?
    gemfile = File.join(@root, "Gemfile")
    return false unless File.exist?(gemfile)

    content = File.read(gemfile)
    content.match?(/^\s*(gemspec|eval_gemfile)\b/) || content.match?(/\bpath:/) ? false : true
  end

  private

  def packages
    list = %w[build-essential git curl pkg-config libyaml-dev libpq-dev libsqlite3-dev]
    list += %w[nodejs npm] if js?
    list
  end

  def js_install_step
    "RUN if [ -f yarn.lock ]; then yarn install || true; else npm install || true; fi"
  end

  def layered_install
    lines = [ "COPY Gemfile* .ruby-version* ./", "RUN bundle install" ]
    if js?
      lines << "COPY package.json yarn.lock* package-lock.json* ./"
      lines << js_install_step
    end
    lines << "COPY . ."
    lines
  end

  def simple_install
    lines = [ "COPY . .", "RUN bundle install" ]
    lines << js_install_step if js?
    lines
  end
end
