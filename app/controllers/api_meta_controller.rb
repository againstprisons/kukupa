class Kukupa::Controllers::ApiMetaController < Kukupa::Controllers::ApiController
  add_route :post, '/'

  def index
    data = {
      site_name: Kukupa.app_config['site-name'],
      org_name: Kukupa.app_config['org-name'],
      base_url: Kukupa.app_config['base-url'],
    }

    if Kukupa.app_config['display-version']
      data[:version] = Kukupa.version
    end

    api_json(data)
  end
end
