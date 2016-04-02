Pod::Spec.new do |spec|
  spec.name = "OHTreesStorageManagerKit"
  spec.version = "1.0.0"
  spec.summary = "Simple framework to provide classes to coordinate model changes between the various storage options"
  spec.homepage = "https://github.com/pbunting/OHTreesStorageManagerKit"
  spec.license = { type: 'GNU', file: 'LICENSE' }
  spec.authors = { "Your Name" => 'your-email@example.com' }

  spec.platform = :ios, "9.1"
  spec.requires_arc = true
  spec.source = { git: "https://github.com/pbunting/OHTreesStorageManagerKit.git", tag: "v#{spec.version}", submodules: true }
  spec.source_files = "OHTreesStorageManagerKit/**/*.{h,swift}"

end

