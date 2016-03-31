class Redirect
  class MissingIdError < StandardError; end
  class NotAllowedError < StandardError; end
  class NotImplimentedError < StandardError; end

  def self.to(default, params, allow:)
    return default if params[:redirect_to].blank?
    allow = [allow].flatten.map(&:to_s)
    raise NotAllowedError if allow.exclude?(params[:redirect_to])

    path_for(params)
  end

  private_class_method def self.path_for(params)
    case params[:redirect_to]
    when "orders"
      Rails.application.routes.url_helpers.orders_path
    when "order"
      Rails.application.routes.url_helpers.order_path(id_from(params))
    else
      raise NotImplimentedError
    end
  end

  private_class_method def self.id_from(params)
    raise MissingIdError if params[:redirect_id].blank?
    params[:redirect_id].to_i
  end
end
