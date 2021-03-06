# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '0519e5d7e335e0698bdda6e1a0eb7b37'

  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user, :invites_left
  helper_method :sidebar_blocks

  unless ActionController::Base.consider_all_requests_local
    rescue_from Exception,                           :with => :render_error
    rescue_from ActiveRecord::RecordNotFound,        :with => :render_not_found
    rescue_from ActionController::RoutingError,      :with => :render_not_found
    rescue_from ActionController::UnknownController, :with => :render_not_found
    rescue_from ActionController::UnknownAction,     :with => :render_not_found
  end

private

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def require_user
    unless current_user
      store_location
      flash[:notice] = "You must be logged in to access this page"
      redirect_to home_path
      return false
    end
  end

  def require_admin
    unless current_user.admin?
      flash[:notice] = "You must be an admin to access this page"
      redirect_to root_path
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = "You must be logged out to access this page"
      redirect_to account_url
      return false
    end
  end

  def store_location
    session[:return_to] = request.request_uri
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  def require_membership
    raise ActiveRecord::RecordNotFound if project.nil?
    membership = project.memberships.find(:first, :conditions => { :user_id => current_user.id })
    raise ActiveRecord::RecordNotFound if membership.nil?
  rescue ActiveRecord::RecordNotFound => e
    flash[:notice] = "You must be a member of this project to access this page"
    redirect_to root_url
    return false
  end

  def require_ownership
    raise ActiveRecord::RecordNotFound if project.nil?
    membership = project.memberships.find(:first, :conditions => { :user_id => current_user.id })
    raise ActiveRecord::RecordNotFound if membership.role != 'owner'
  rescue ActiveRecord::RecordNotFound => e
    flash[:notice] = "You must be the owner of this project to access this page"
    redirect_to root_path
    return false
  end

  def project ; nil ; end

  def sidebar_blocks
    @sidebar_blocks ||= {}
  end

  def invites_left(total=nil)
    unless total.nil?
      users = User.find(:all)
      admins = users.select { |x| x.admin }
      %{#{ total - users.length + admins.length }}
    end
  end

  def render_not_found(exception)
    Rails.logger.info exception
    render :template => "/error_pages/404.html.haml",
           :status => 404,
           :layout => 'error.html.haml'
  end

  def render_error(exception)
    Rails.logger.error exception
    render :template => "/error_pages/500.html.haml",
           :status => 404,
           :layout => 'error.html.haml'
  end

end