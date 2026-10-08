# GOV.UK's default ESM entry point imports files that importmap does not vendor.
# Use the self-contained distribution for the version resolved by importmap.
module GovukFrontendPackager
  def import(...)
    result = super
    imports = result&.fetch(:imports)
    url = imports&.fetch("govuk-frontend", nil)
    return result unless url

    version = url[%r{govuk-frontend@(\d+\.\d+\.\d+)/}, 1]
    raise Importmap::Packager::Error, "Cannot resolve GOV.UK Frontend bundle version from #{url}" unless version

    imports["govuk-frontend"] = "https://cdn.jsdelivr.net/npm/govuk-frontend@#{version}/dist/govuk/govuk-frontend.min.js"
    result
  end

  def download(package, url)
    super
    return unless package == "govuk-frontend"

    path = vendor_path.join("govuk-frontend.js")
    path.write("#{path.read.rstrip}\n")
  end
end
