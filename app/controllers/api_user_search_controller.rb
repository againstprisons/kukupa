class Kukupa::Controllers::ApiUserSearchController < Kukupa::Controllers::ApiController
  add_route :get, '/'
  add_route :post, '/'

  def initialize(*args)
    super

    @api_token_check_params = {
      allow_user_session: true,
    }
  end

  def index
    if @current_user
      unless @current_user.has_role?('user:search')
        return api_json({
          success: false,
          error: 'NO_PERMISSIONS',
        })
      end
    end

    # get our query
    query = request.params['query']&.strip&.downcase
    query = nil if query&.empty?
    if query.nil?
      return api_json({
        success: false,
        error: 'INVALID_QUERY',
      })
    end

    # get potential user IDs for each query part
    query_parts = query.split(' ').map do |qp|
      if (uid = /\#(\d+)/.match(qp)&.[](1).to_i).positive?
        [uid]
      else
        Kukupa::Models::UserFilter.perform_filter(:name, qp).map(&:user)
      end
    end

    # pick out users that match all query parts
    users = query_parts.flatten.compact.uniq.map do |uid|
      if query_parts.map{|p| p.include?(uid)}.all?
        Kukupa::Models::User[uid]
      end
    end.compact

    # gather user information
    users.map! do |user|
      tags = user.roles.map{|r| /tag\:(\w+)/.match(r)&.[](1)}.compact.uniq.map do |tag|
        {
          tag: tag,
          display: t("tag/#{tag}".to_sym),
        }
      end

      {
        uid: user.id,
        name: user.decrypt(:name),
        email: user.email,
        tags: tags,
      }
    end

    api_json({
      success: true,
      users: users,
    })
  end
end
