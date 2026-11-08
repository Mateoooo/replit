require "rails_helper"

RSpec.describe PlatformDockerfile do
  let(:root) { Dir.mktmpdir("dockerfile-spec") }

  after { FileUtils.remove_entry(root) }

  def render(files = {})
    { "Gemfile" => "source 'https://rubygems.org'\ngem 'rails'\n" }.merge(files).each do |name, content|
      File.write(File.join(root, name), content)
    end
    described_class.new(root).render
  end

  describe "#render" do
    context "для обычного Rails-проекта (happy path)" do
      it "запускает Rails в режиме development на порту 3000" do
        dockerfile = render

        expect(dockerfile).to include("FROM ruby:3.3")
        expect(dockerfile).to include("RAILS_ENV=development")
        expect(dockerfile).to include("EXPOSE 3000")
        expect(dockerfile).to include("rails server -b 0.0.0.0 -p 3000")
      end

      it "запускает сервер через exec, чтобы он получал сигнал остановки и гас быстро" do
        expect(render).to include("&& exec bundle exec rails server")
      end

      it "берёт версию Ruby из .ruby-version" do
        expect(render(".ruby-version" => "3.2.2\n")).to include("FROM ruby:3.2.2")
      end

      it "ставит зависимости ДО копирования кода — чтобы правки кода не сбрасывали кеш bundle install" do
        dockerfile = render

        expect(dockerfile).to include("COPY Gemfile* .ruby-version* ./")
        expect(dockerfile.index("RUN bundle install")).to be < dockerfile.index("COPY . .")
      end
    end

    context "с Node-зависимостями" do
      it "подключает Node и ставит пакеты до копирования кода" do
        dockerfile = render("package.json" => "{}")

        expect(dockerfile).to include("nodejs npm")
        expect(dockerfile).to include("COPY package.json yarn.lock* package-lock.json* ./")
        expect(dockerfile.index("yarn install")).to be < dockerfile.index("COPY . .")
      end

      it "не добавляет Node, если package.json нет" do
        expect(render).not_to include("nodejs npm")
      end
    end

    context "когда Gemfile ссылается на локальные файлы проекта" do
      it "копирует проект целиком до bundle install (раздельные слои сломали бы сборку)" do
        dockerfile = render("Gemfile" => "source 'https://rubygems.org'\ngem 'engine', path: 'vendor/engine'\n")

        expect(dockerfile.index("COPY . .")).to be < dockerfile.index("RUN bundle install")
      end

      it "то же для gemspec" do
        dockerfile = render("Gemfile" => "source 'https://rubygems.org'\ngemspec\n")

        expect(dockerfile).not_to include("COPY Gemfile* .ruby-version* ./")
      end
    end

    context "для старых образов Ruby" do
      it "переключает apt на archive.debian.org (иначе сборка на Debian buster падает)" do
        expect(render).to include("archive.debian.org")
      end
    end
  end

  describe "#write" do
    it "создаёт файл Dockerfile.platform в папке проекта" do
      File.write(File.join(root, "Gemfile"), "source 'https://rubygems.org'")

      described_class.new(root).write

      expect(File.read(File.join(root, "Dockerfile.platform"))).to include("FROM ruby:")
    end
  end
end
