# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
not_declared_trivial = !(github.pr_title.include? "#trivial")
has_app_changes = !git.modified_files.grep(/Sources/).empty?

# ENSURE THAT LABELS HAVE BEEN USED ON THE PR
fail "Please add labels to this PR" if github.pr_labels.empty?

# Mainly to encourage writing up some reasoning about the PR, rather than just leaving a title
if github.pr_body.length < 5
  fail "Please provide a summary in the Pull Request description"
end

# Pay extra attention if external contributors modify certain files
if git.modified_files.include?("LICENSE.txt")
  fail "External contributor has edited the LICENSE.txt"
end
if git.modified_files.include?("Gemfile") or git.modified_files.include?("Gemfile.lock")
  warn "External contributor has edited the Gemfile and/or Gemfile.lock"
end
if git.modified_files.include?("Eval.podspec") or git.modified_files.include?("Package.swift")
  warn "External contributor has edited the Eval.podspec and/or Package.swift"
end

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "WIP"

# Warn when there is a big PR
warn("Big PR, try to keep changes smaller if you can") if git.lines_of_code > 500

# Changelog entries are required for changes to library files.
no_changelog_entry = !git.modified_files.include?("Changelog.md")
if has_app_changes && no_changelog_entry && not_declared_trivial
  #warn("Any changes to library code should be reflected in the Changelog. Please consider adding a note there")
end

# Added (or removed) library files need to be added (or removed) from the Carthage Xcode project to avoid breaking things for our Carthage users.
added_swift_library_files = !(git.added_files.grep(/Sources.*\.swift/).empty?)
deleted_swift_library_files = !(git.deleted_files.grep(/Sources.*\.swift/).empty?)
modified_carthage_xcode_project = !(git.modified_files.grep(/Eval\.xcodeproj/).empty?)
if (added_swift_library_files || deleted_swift_library_files) && !modified_carthage_xcode_project
  warn("Added or removed library files require the Carthage Xcode project to be updated")
end

missing_doc_changes = git.modified_files.grep(/Documentation/).empty?
doc_changes_recommended = git.insertions > 15
if has_app_changes && missing_doc_changes && doc_changes_recommended && not_declared_trivial
  warn("Consider adding supporting documentation to this change. Documentation can be found in the `Documentation` directory.")
end

# Warn when library files has been updated but not tests.
tests_updated = !git.modified_files.grep(/Tests/).empty?
if has_app_changes && !tests_updated
  warn("The library files were changed, but the tests remained unmodified. Consider updating or adding to the tests to match the library changes.")
end

# Give inline build results (compile and link time warnings and errors)
xcode_summary.report 'build/tests/summary.json' if File.file?('build/tests/summary.json')
xcode_summary.report 'build/example/summary.json' if File.file?('build/example/summary.json')

# Run SwiftLint
swiftlint.lint_files
#swiftlint.lint_files inline_mode: true
