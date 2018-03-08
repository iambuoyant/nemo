# frozen_string_literal: true

require "fileutils"

namespace :scss do
  desc "Preprocess application.scss to create combinations for themes and LTR/RTL."
  task preprocess: :environment do
    styles_dir = Rails.root.join("app", "assets", "stylesheets")
    app_scss_file = styles_dir.join("application.scss")
    themes_dir = styles_dir.join("all", "themes")
    %w[nemo elmo custom].each do |theme|
      next unless File.exist?(themes_dir.join("_#{theme}_theme.scss"))

      %w[ltr rtl].each do |direction|
        File.open(File.join(styles_dir, "application_#{theme}_#{direction}.scss"), "w") do |f|
          app_scss = replace_top_comment(File.read(app_scss_file))
          app_scss.gsub!("@@@theme@@@", "#{theme}_theme")
          app_scss.gsub!("@@@direction@@@", direction)
          f.write(app_scss)
        end
      end
    end
  end

  def replace_top_comment(scss)
    lines = scss.split("\n")
    loop { lines[0].match?(%r{\A(//|\w*\z)}) ? lines.shift : break }
    +"// THIS FILE IS AUTO-GENERATED BY rake scss:preprocess. DO NOT EDIT DIRECTLY!\n\n" <<
      lines.join("\n")
  end
end
