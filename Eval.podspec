Pod::Spec.new do |s|
  s.name = "Eval"
  s.version = "1.5.0"
  s.summary = "Eval is a lightweight interpreter framework written in  Swift, evaluating expressions at runtime"
  s.description = <<-DESC
Eval is a lightweight interpreter framework written in Swift, for 📱iOS, 🖥 macOS, and 🐧Linux platforms.

It evaluates expressions at runtime, with operators and data types you define.
                   DESC
  s.homepage = "https://tevelee.github.io/Eval/"
  s.license = { :type => "Apache 2.0", :file => "LICENSE.txt" }
  s.author = { "Laszlo Teveli" => "tevelee@gmail.com" }
  s.social_media_url = "http://twitter.com/tevelee"
  s.source = { :git => "https://github.com/tevelee/Eval.git", :tag => "#{s.version}" }
  s.source_files = "Sources/**/*.{h,swift}"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
end
