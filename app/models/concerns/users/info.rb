module Users
  module Info
    extend ActiveSupport::Concern

    def super_admin?
      role == "admin"
    end

    def admin?
      super_admin? || organizations.any? { |org| admin_at?(org) }
    end

    def admin_at?(organization)
      super_admin? || role_at(organization) == "admin"
    end

    def member_at?(organization)
      organization_user_at(organization).present?
    end

    def show_detailed_exceptions?
      super_admin?
    end

    def can_backup?
      super_admin?
    end

    def can_export?
      super_admin?
    end

    def can_view_profiler_results?
      super_admin?
    end

    def closed_orders_with_access
      if super_admin?
        @closed_orders_with_access ||= Order.includes(:organization).includes(:order_details).includes(:shipments).where(status: 6)
      else
        orders.includes(:order_details).includes(:shipments).where(status: 6)
      end
    end

    def rejected_orders_with_access
      if super_admin?
        @rejected_orders_with_access ||= Order.includes(:organization).includes(:order_details).includes(:shipments).where(status: 2)
      else
        orders.includes(:order_details).includes(:shipments).where(status: 2)
      end
    end

    def orders_with_access
      if super_admin?
        @orders_with_access ||= Order.includes(:organization).includes(:order_details).includes(:shipments).where.not(status: [6, 2]) # not rejected or closed
      else
        orders.includes(:order_details).includes(:shipments).where.not(status: [6, 2]) # not rejected or closed
      end
    end

    def organizations_with_access
      if super_admin?
        @organizations_with_access ||= Organization.order(name: :asc)
      else
        organizations.order(name: :asc)
      end
    end

    def organizations_with_permission_enabled(permission, options = {})
      organizations = organizations_with_access
      organizations = organizations.includes(options[:includes]) if options.include?(:includes)
      filter_organizations_with_permission_enabled(organizations, permission)
    end

    def filter_organizations_with_permission_enabled(organizations, permission)
      if super_admin?
        organizations
      else
        organizations.select do |organization|
          send(permission, organization)
        end
      end
    end

    def organization_user_at(organization)
      organization_users.find do |org_user|
        org_user.organization_id == organization.id
      end
    end

    def role_at(organization)
      org_user = organization_user_at(organization)
      org_user.role if org_user
    end
  end
end
