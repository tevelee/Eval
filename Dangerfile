# Mainly to encourage writing up some reasoning about the PR, rather than just leaving a title
if github.pr_body.length < 5
  fail "Please provide a summary in the Pull Request description"
end

# Just to let people know
warn("PR is classed as Work in Progress") if github.pr_title.include? "WIP"

# Pay extra attention if external contributors modify certain files
if git.modified_files.include?("Gemfile") or git.modified_files.include?("Gemfile.lock")
  warn "External contributor has edited the Gemfile and/or Gemfile.lock"
end
if git.modified_files.include?("Eval.podspec") or git.modified_files.include?("Package.swift")
  warn "External contributor has edited the Eval.podspec and/or Package.swift"
end
if git.modified_files.include?("LICENSE.txt")
  fail "External contributor has edited the LICENSE.txt"
end

# Give inline build results (compile and link time warnings and errors)
xcode_summary.report 'build/tests/summary.json' if File.file?('build/tests/summary.json')
xcode_summary.report 'build/example/summary.json' if File.file?('build/example/summary.json')
