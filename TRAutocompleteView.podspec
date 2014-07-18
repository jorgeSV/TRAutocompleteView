Pod::Spec.new do |s|
  s.name         = "TRAutocompleteView"
  s.version      = “1.2”
  s.summary      = "Flexible and highly configurable auto complete view, attachable to any UITextField."

  s.homepage     = "https://github.com/jorgeSV/TRAutocompleteView"
  s.license      = 'FreeBSD'
  s.author       = { "Taras Roshko" => "taras.roshko@gmail.com”, “Jorge Souto” => “amk114@gmail.com” }

  s.source       = { :git => "https://github.com/jorgeSV/TRAutocompleteView.”git, :tag => "v1.2” }
  s.platform     = :ios, ‘6.1’
  s.source_files = 'src'
  s.requires_arc = true
  
  s.frameworks = 'CoreLocation'
  s.dependency 'AFNetworking'
end
