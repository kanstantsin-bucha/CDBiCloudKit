#
# Be sure to run `pod lib lint CDBiCloudReadyDocumentsContainer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

@version = "1.1.0"

Pod::Spec.new do |s|
  s.name             = "CDBiCloudKit"
  s.version          = @version
  s.summary          = "Documents, CoreData Kit for iCloud"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
    CDBCloudConnection maintains connection to a Cloud and provide helpful states.
    CDBCloudStore provide enable/disable and CRUD for CoreData iCloud store and remove duplicates logic.
    CDBDocumentContainer provide CRUD for documents in iCloud.
    CDBDocument provides document file states and user friendly properties to check them.
                       DESC

  s.homepage         = "https://github.com/truebucha/CDBiCloudKit"
  s.license          = 'MIT'
  s.author           = { "yocaminobien" => "truebucha@gmail.com" }
  s.source           = { :git => "https://github.com/truebucha/CDBiCloudKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/truebucha'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'CDBiCloudKit/Classes/**/*'
  s.frameworks = 'UIKit', 'CoreData'
  s.dependency 'CDBKit', '~> 0.0'
  s.dependency 'CDBUUID', '~> 1.0.0'
end
