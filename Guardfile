# # hack to make guard-css compile with sourcemap
#
# require 'guard/sass'
# require 'guard/sass/importer'
# require 'sass/exec'
# class ::Guard::Sass::Importer
#   def root
#     "/Users/amadan/work/fixfix/public"
#   end
# end
# class ::Guard::Sass::Runner
#   puts self
#   def compile(file)
#     sass_options = {
#       :filesystem_importer => ::Guard::Sass::Importer,
#       :load_paths          => options[:load_paths],
#       :style               => options[:style],
#       :debug_info          => options[:debug_info],
#       :line_numbers        => options[:line_numbers],
#     }
# 
#     sourcemap_file = File.basename(file).gsub(/(\.s?[ac]ss)+/, options[:extension] + '.map')
#     css, sourcemap = ::Sass::Engine.for_file(file, sass_options).render_with_sourcemap(sourcemap_file)
#     dir = get_output_dir(file)
#     sourcemap_path = File.join(dir, sourcemap_file)
#     sourcemap_json = sourcemap.to_json(css_path: dir, sourcemap_path: dir)
# 
#     unless options[:noop]
#       FileUtils.mkdir_p(dir)
#       File.open(sourcemap_path, 'w') { |f| f.write(sourcemap_json) }
#     end
# 
#     css
#   end
# end

guard 'rack', :port => 9292 do
  watch 'Gemfile.lock'
  watch %r{^models/.*}
  watch %r{^routes/.*}
  watch %r{^lib/.*}
  watch 'app.rb'
  watch 'config.yaml'
end

guard 'coffeescript',
    :input => 'assets/coffeescript',
    :output => 'public/js',
    :source_map => true

guard 'sass',
#     :debug_info => true,
    :input => 'assets/sass',
    :output => 'public/css'
