Dir.glob('**/*.framework/').each do |fw|
  Dir.chdir(fw) do
    basename = File.basename(fw, '.framework')
    FileUtils.rm_f(basename)
    FileUtils.rm_f('Versions/Current')
    FileUtils.rm_f('Resources')

    File.symlink('A', 'Versions/Current')
    File.symlink("Versions/Current/#{basename}", "#{basename}")
    File.symlink('Versions/Current/Resources', 'Resources')
  end
end

# make sure environment is UTF-8 (CI sometimes thinks it's ASCII)
ENV['LANG'] = 'en_US.UTF-8'
ENV['LANGUAGE'] = 'en_US.UTF-8'
ENV['LC_ALL'] = 'en_US.UTF-8'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# allow requiring of .rb files in ‘Scripts/lib' and some common libraries
$LOAD_PATH.unshift File.expand_path('Scripts/lib', File.dirname(__FILE__))

# load all rake tasks
Dir.glob('Scripts/*.rake').each { |r| import r }