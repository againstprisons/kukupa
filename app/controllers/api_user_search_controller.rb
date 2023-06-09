require 'active_model'
require 'email_validator'

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
      allowed_perms = [
        @current_user.has_role?('user:search'),
        @current_user.has_role?('case:assignable'),
      ]

      if allowed_perms.none?
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
    query_parts = query.split(/\s+/).map do |qp|
      qp.strip!
      next nil if qp.empty?

      # is this a user ID?
      if (uid = /\#(\d+)/.match(qp)&.[](1).to_i).positive?
        [uid]

      # is this an email address?
      elsif EmailValidator.valid?(qp)
        Kukupa::Models::User
          .select(:id, :email)
          .where(email: qp)
          .map(&:id)
      
      # is this a partial tag?
      elsif !((partialtag = /\!(\w+)/.match(qp)&.[](1)&.downcase).nil?)
        partialtag_uids = []

        tags = Kukupa.languages[Kukupa.default_language].keys.map do |tlkey|
          tag = /^tag\/(\w+)$/.match(tlkey.to_s)&.[](1)&.downcase
          next nil unless tag

          unless tag.include?(partialtag)
            unless t(tlkey).downcase.include?(partialtag)
              next nil
            end
          end

          tlkey.to_s.gsub('/', ':')
        end.compact
        
        tags.each do |role|
          partialtag_uids << Kukupa::Models::UserRole.where(role: role).map(&:user_id)

          Kukupa::Models::RoleGroupRole.where(role: role).map do |rgr|
            partialtag_uids << rgr.role_group.role_group_users.map(&:user_id)
          end
        end

        partialtag_uids.flatten.compact.uniq

      # nothing above matched, treat as a partial name
      else
        Kukupa::Models::UserFilter.perform_filter(:name, qp).map(&:user)
      end
    end.compact

    # pick out users that match all query parts
    users = query_parts.flatten.compact.uniq.map do |uid|
      if query_parts.map{|p| p.include?(uid)}.all?
        Kukupa::Models::User[uid]
      end
    end.compact

    # if we've been asked to only show assignable users, filter the user
    # list by whether the users have the "case:assignable" role
    if request.params['only_assignable'].to_i.positive?
      users = users.map do |user|
        next nil unless user.has_role?('case:assignable')
        next nil if user.is_at_case_limit?
        user
      end.compact
    end

    # if we've been asked to only show users assigned to the given case,
    # filter by CaseAssignedAdvocate
    if (case_id = request.params['only_case_assigned'].to_i).positive?
      users = users.map do |user|
        is_assigned = Kukupa::Models::CaseAssignedAdvocate
          .where(case: case_id, user: user.id)
          .count
          .positive?

        unless is_assigned
          unless user.has_role?('case:view_all')
            next nil
          end
        end

        user
      end.compact
    end

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
