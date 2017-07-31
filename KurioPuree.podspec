Pod::Spec.new do |s|
  s.name             = "KurioPuree"
  s.version          = "3.0.0"
  s.summary          = "A log collector for iOS, modified for Kurio"
  s.homepage         = "https://github.com/managam/puree-ios"
  s.license          = "MIT"
  s.author           = { "Tomohiro Moro" => "tomohiro-moro@cookpad.com", "Managam Silalahi" => "managam.silalahi@gmail.com" }
  s.source           = { :git => "https://github.com/managam/puree-ios.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'

  s.dependency 'YapDatabase', '~> 2.9.2'
end
